# CacheFS ATC'26 Artifact Evaluation

> **Binary-only scope.** This artifact distributes a fixed prebuilt CacheFS image, not the CacheFS core implementation source. Evaluators can execute the image and inspect or modify the public orchestration scripts and documentation, but cannot inspect, modify, or rebuild the CacheFS core at source level.

The default Reproduced path uses a privately staged, evaluator-obtained Qwen2.5-72B-Instruct snapshot. The public repository contains no model weights, production traces, credentials, or private host configuration.

Reserved version-specific Zenodo DOI: `10.5281/zenodo.23167350`.

## Scope

The artifact demonstrates:

- transparent FUSE access to unmodified immutable Qwen weight files;
- source-backed fill on one CacheFS node;
- Serf discovery and TCP peer-served reads on a shardless second node;
- SHA-256 file integrity and CacheFS source/peer/checksum counters; and
- optional broadcast preload and low-scale warm-burst workflows.

Synthetic data remains available only as a quick Functional smoke test. The artifact does **not** reproduce production-scale experiments, 50-node scale-out, cloud-storage results, published model-loading speedups, CacheRoot, RDMA, GPU savings, fault injection, TCO, or comparisons with other systems. The artifact validates the FUSE/POSIX model-file delivery path exposed to unmodified inference engines; it does not run end-to-end vLLM or SGLang startup or inference. Timing outputs are diagnostic only and are not paper-performance claims.

## Image

The default registry path uses this immutable OCI index:

```text
eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs@sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7
```

The registry permits anonymous pulls without an Alibaba Cloud account and publishes `linux/amd64` and `linux/arm64` manifests. Network reachability can vary by environment. See [docs/image-provenance.md](docs/image-provenance.md) for the platform digests, binary and dependency versions, and the documented provenance fallback. This binary-only artifact does not include a Dockerfile or source-based build context.

### Offline image (recommended registry-independent amd64 path)

The repository includes a `linux/amd64` image tarball, which will also be included in the final Zenodo record. It is covered by the release manifest and can be used without registry access. It does not support `linux/arm64`.

```sh
# Verify, then load on every node (both A and B for multi-host):
sha256sum -c - <<'EOF'
3f6fef905bfde8d101162bc620cadcc7deb18044f6d8a4ec182a85dacbaa40c2  dist/cachefs-3.7-amd64.tar.gz
EOF
gunzip -c dist/cachefs-3.7-amd64.tar.gz | docker load   # loads cachefs-ae:3.7

# Run any workflow against the local image with registry pulls disabled:
export IMAGE_REF=cachefs-ae:3.7
export PULL_IMAGE=0
bash scripts/preflight.sh --multihost
```

## Requirements

- Linux x86_64 or aarch64 host(s), Docker, Bash, Python 3, and `sha256sum`.
- Docker access with `--privileged` and `/dev/fuse` available.
- For multi-host evaluation: two Linux machines with passwordless SSH access from the coordinator (node-specific SSH ports are supported), routable node IPs, and firewall access for CacheFS TCP `17888` and Serf TCP/UDP `17999`.

| Workflow | Cache memory | Additional capacity |
| --- | --- | --- |
| Functional loopback | About 2 GiB total RAM/disk | No model download |
| Default 72B peer-read/preload | At least 160 GiB available cache memory per node | Additional RAM for the OS and Docker; at least 160 GiB staging disk on node A |
| Lower-RAM 7B peer-read/preload | About 20 GiB available cache memory per node | Additional RAM for the OS and Docker; about 20 GiB staging disk on node A |

The 72B scripts default to a 180 GiB cache (`MODEL_CACHE_MIB=184320`). The optional warm-burst workflow starts two consumers on node B by default, each with a 192 GiB cache ceiling (`B_CACHE_MIB=196608`), for a 384 GiB aggregate ceiling. These values are overridable settings, not minimum physical-memory requirements. The configured cache must remain larger than the selected model's on-disk working set.

For an optional account-specific Alibaba Cloud deployment reference, see [Alibaba Cloud EAS Deployment Reference](docs/alibaba-cloud-eas-deployment.md). It does not replace the binary-image validation workflows below.

## Default Reproduced path: real Qwen weights

```sh
cp config/hosts.example.env config/hosts.env
cp config/model.example.env config/model.env
# Edit both private files. Accept the Qwen license before downloading.
I_ACCEPT_MODEL_LICENSE=1 bash scripts/fetch-qwen-modelscope.sh
bash scripts/preflight.sh --multihost
bash scripts/run-real-qwen-peer-read.sh
bash scripts/run-preload-broadcast.sh
```

Node A privately stages the model. Node B receives no pre-staged model shards and reads every file listed in its local manifest through CacheFS peers with zero source reads. See [docs/model-data.md](docs/model-data.md) for the model-license and non-redistribution boundary.

### Lower-RAM option: smaller model

The two-host mechanism test is model-agnostic, so a smaller model lowers the RAM requirement. To validate with `Qwen2.5-7B-Instruct` (bf16 about 15 GB) instead of the 72B default, set these values in `config/model.env`:

```sh
MODEL_ID=Qwen/Qwen2.5-7B-Instruct
MODEL_REVISION=16c174980d8a1492910551634b4969e69cdc2444
MODEL_SOURCE_A=/path/to/private/Qwen2.5-7B-Instruct
MODEL_MANIFEST_A=/path/to/private/Qwen2.5-7B-Instruct.manifest.sha256
MODEL_METADATA_A=/path/to/private/Qwen2.5-7B-Instruct.manifest.json
MODEL_LICENSE_URL=https://modelscope.cn/models/Qwen/Qwen2.5-7B-Instruct
EXPECTED_SAFETENSOR_SHARDS=4   # must equal the model's actual .safetensors count
MODEL_CACHE_MIB=20480          # memory-backed cache (MiB); keep it above the model size
MODEL_SOURCE_ID=qwen2.5-7b-instruct-ae
```

Then stage and run exactly as the default path; both nodes now need only about 20 GiB of free RAM:

```sh
cp config/hosts.example.env config/hosts.env   # edit hosts as usual
I_ACCEPT_MODEL_LICENSE=1 bash scripts/fetch-qwen-modelscope.sh
bash scripts/preflight.sh --multihost
bash scripts/run-real-qwen-peer-read.sh
bash scripts/run-preload-broadcast.sh
```

`EXPECTED_SAFETENSOR_SHARDS` must match the chosen model or `verify-model-manifest.py` aborts; keep `MODEL_CACHE_MIB` above the model's on-disk size (reported as `total_bytes` in the metadata file). The correctness criteria are the same as for the 72B path: node A performs the source-backed fill and node B records full-manifest peer hits with zero source reads and zero checksum errors.

## Quick Functional smoke test

```sh
bash scripts/preflight.sh --loopback
bash scripts/run-loopback-functional.sh
```

This synthetic-data test verifies installation, FUSE, networking, and peer reads; it is not the default model-weight reproduction path.

`config/hosts.env`, `config/model.env`, model files, SSH keys, logs, and results are intentionally ignored by Git.

## Results and cleanup

Every invocation creates `runs/<timestamp>/`. The scripts collect JSON/CSV/Markdown summaries and attempt to remove Docker containers, FUSE mounts, and temporary remote directories on normal completion, failure, or interruption. If a run is interrupted, see [docs/validation.md](docs/validation.md).

## License and notices

The CacheFS binary is distributed under the [Apache License, Version 2.0](LICENSE). The same license applies to the public artifact scripts and documentation. The container image also includes third-party components under their respective licenses; see [NOTICE](NOTICE).

## Support

Please report artifact issues through the [repository issue tracker](https://github.com/gnehzuil/cachefs-atc26-ae/issues).
