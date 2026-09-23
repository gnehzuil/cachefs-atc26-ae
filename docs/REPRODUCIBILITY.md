# Reproducibility Requirements

## Functional smoke

- One Linux x86_64 or aarch64 host, Docker, Bash, Python 3, `sha256sum`, and `/dev/fuse`.
- Docker permission for `--privileged`, `/dev/fuse`, and host networking.
- About 2 GiB RAM/disk and 15 minutes.

## Default real-Qwen path

- Two Linux x86_64 or aarch64 hosts with passwordless SSH from the coordinator; routable network addresses; CacheFS TCP `17888` and Serf TCP/UDP `17999` allowed both directions.
- Node A: at least 160 GiB available RAM for cachefs cache.
- Node B: at least 160 GiB available RAM for a full peer cache.
- Evaluator has accepted the Qwen2.5-72B-Instruct model license and can obtain the model from ModelScope.
- Expected time: model acquisition depends on mirror bandwidth; sha256sum checksum on model files, peer manifest, and preload each may take tens of minutes on modest storage/network paths.

## Optional SGLang smoke

- Node B must have NVIDIA Container Toolkit, compatible driver/runtime, and enough GPU memory for the selected tensor-parallel degree plus framework headroom.
- The official SGLang image digest must be available and recorded before use.

## Result interpretation

Model-file integrity, source/peer counters, checksum counters, and successful SGLang smoke startup are correctness evidence. Wall-clock times are diagnostic for the evaluator's topology; they are not replications of paper-scale performance figures.
