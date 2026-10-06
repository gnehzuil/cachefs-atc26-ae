# Reproducibility Requirements

## Functional smoke

- One Linux x86_64 host, Docker, Bash, Python 3, `sha256sum`, and `/dev/fuse`.
- Docker permission for `--privileged`, `/dev/fuse`, and host networking.
- About 2 GiB RAM/disk and 15 minutes.

The registry publishes both `linux/amd64` and `linux/arm64` manifests, but the bundled offline image and documented validation cover `linux/amd64` only.

## Default real-Qwen path

- Two Linux x86_64 hosts with passwordless SSH from the coordinator; routable network addresses; CacheFS TCP `17888` and Serf TCP/UDP `17999` allowed both directions.
- Each node: at least 160 GiB of memory available to the CacheFS cache, plus headroom for the OS and Docker.
- Node A: at least 160 GiB of staging disk for the privately downloaded model.
- The scripts default to a 180 GiB cache (`MODEL_CACHE_MIB=184320`). The optional warm-burst workflow starts two consumers on node B by default, each with a 192 GiB cache ceiling (`B_CACHE_MIB=196608`), for a 384 GiB aggregate ceiling. These values are overridable settings, not minimum physical-memory requirements.
- Evaluator has accepted the Qwen2.5-72B-Instruct model license and can obtain the pinned model revision from ModelScope.
- Expected time: model acquisition depends on mirror bandwidth; sha256sum checksum on model files, peer manifest, and preload each may take tens of minutes on modest storage/network paths.

## Lower-RAM real-Qwen path

The documented Qwen2.5-7B-Instruct profile uses a 20 GiB cache per node. Hosts also need additional memory for the OS and Docker, and node A needs enough staging disk for the model snapshot.

## Result interpretation

Model-file integrity, source/peer counters, and checksum counters are correctness evidence. Wall-clock times are diagnostic for the evaluator's topology; they are not replications of paper-scale performance figures.
