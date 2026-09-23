# CacheFS ATC'26 Artifact Evaluation

This public artifact evaluates the CacheFS binary image. The default Reproduced path uses a privately staged, evaluator-obtained Qwen2.5-72B-Instruct snapshot; the public repository contains no CacheFS source code, model weights, production traces, credentials, or internal endpoints.

## Scope

The artifact demonstrates:

- transparent FUSE access to unmodified immutable Qwen weight files;
- source-backed fill on one CacheFS node;
- Serf discovery and TCP peer-served reads on a shardless second node;
- SHA-256 file integrity and CacheFS source/peer/checksum counters;
- optional broadcast preload, cache-pressure, low-scale warm-burst, and SGLang smoke workflows.

Synthetic data remains available only as a quick Functional smoke test. The artifact does **not** reproduce production-scale experiments, 50-node scale-out, cloud-storage results, published model-loading speedups, CacheRoot, RDMA, GPU savings, fault injection, TCO, or comparisons with other systems. Timing outputs are diagnostic only and are not paper-performance claims.

## Image

All scripts use this immutable image reference:

```text
eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs@sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7
```

The discovery tag is `3.7`; see [docs/image-provenance.md](docs/image-provenance.md) for the observed version and platform.

## Requirements

- Linux x86_64 or aarch64 host(s), Docker, Bash, Python 3, and `sha256sum`.
- Docker access with `--privileged` and `/dev/fuse` available.
- For multi-host evaluation: two Linux machines with passwordless SSH access from the coordinator (node-specific SSH ports are supported), routable node IPs, and firewall access for CacheFS TCP `17888` and Serf TCP/UDP `17999`.

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

Node A privately stages the model. Node B receives no raw shard copy and must read the Qwen manifest from peers with zero source reads. See [docs/model-data.md](docs/model-data.md) for the model-license and non-redistribution boundary.

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

The public CacheFS binary image is distributed under Apache-2.0 as confirmed by the artifact authors. See [LICENSE](LICENSE) and [NOTICE](NOTICE). The artifact scripts are also Apache-2.0.

## Support

Before public release, replace this placeholder with the monitored AE contact address. Do not include credentials or private host details in public issues.
