# Reproduction Coverage Matrix

These AE scenarios validate selected mechanisms in the submitted CacheFS paper. They do not reproduce the paper's production-scale performance results.

| Paper mechanism | Public AE scenario | Evidence captured | Not claimed |
| --- | --- | --- | --- |
| Read-only FUSE path, source-backed cache, peer lookup (§3–§4) | Synthetic Functional smoke | Node A source reads; node B peer hits; SHA-256 checks; zero checksum errors; cleanup | Production-model performance or any published speedup |
| Real immutable model distribution (§5.2) | Qwen source-ready / shardless peer-manifest | Private model revision/manifest digest; file/shard count; B peer-only counters; integrity | 50/100-instance results, 56×/44×, NFS/object-store comparison |
| Broadcast preload (§5.6) | Real Qwen `preload --broadcast` | A source-ready counters; B preload peer bytes/hits; B zero source reads; manifest verification | Reported 7–41%/27% gains or framework-init overlap |
| Warm P2P burst (§5.4) | Real Qwen 2–4 consumer warm burst | Per-consumer shard checks, peer/source bytes, coordinator wall time | Near-constant completion through 400 nodes or tail guarantees |
| TCP data path (§5.3) | Optional real-Qwen TCP diagnostic | Fixed image, aggregate peer bytes, wall time, counter deltas, integrity | 140 Gbps, gRPC comparison, RDMA, or paper-scale throughput |

Not covered: end-to-end vLLM/SGLang startup or inference, the hash-aware versus 2-random eviction comparison, CacheRoot, production NFS/object-store baselines, RDMA, GPU-hour savings, fleet deployment, fault injection, or external-system comparisons.
