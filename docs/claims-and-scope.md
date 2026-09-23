# Claims and Scope

## Validated by this artifact

The default scripts validate the following mechanisms with a complete privately staged Qwen2.5-72B-Instruct weight snapshot obtained by the evaluator under its license:

1. CacheFS exposes the unmodified model tree through a FUSE mount.
2. Node A reads and caches the model from its local source directory.
3. A shardless node B joins node A through Serf, reads the same Qwen manifest through peers, and records peer hits without source reads.
4. File SHA-256 values match the model manifest, while peer-transfer checksum errors remain zero.

Synthetic fixtures are limited to installation and networking smoke tests.

These checks correspond to the paper's loader-facing file path, peer discovery, and cooperative peer-read mechanisms.

## Not evaluated

This artifact does not reproduce or claim the paper's production-scale results, 50-node scale-out, cloud NFS/object-storage behavior, CacheRoot, RDMA, GPU utilization/cost savings, availability under failures, or comparisons with 3FS, Dragonfly, Ceph, parallel NFS, or optimized object storage. Optional eviction, warm-burst, and TCP diagnostics use different hardware/topology from the paper and report only scoped observations.

The repeated-test elapsed time is diagnostic. It is not a reproduction of any published paper figure or performance number.
