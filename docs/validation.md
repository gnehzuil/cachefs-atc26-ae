# Validation Guide

## Success criteria

A successful Functional run creates `result.json` with:

- `node_a.source_reads > 0`;
- `node_a.remote_hits == 0` before node B reads;
- `node_b.remote_hits > 0`;
- `node_b.source_reads == 0`;
- `node_b.checksum_errors == 0`.

The repeated subset emits JSON, CSV, and Markdown summaries. Each iteration must satisfy the same counter assertions.

## Observed anonymous validation

The fixed image digest was validated on two Linux x86_64 hosts with Docker, FUSE, and routable Ethernet addresses. Three synthetic multihost runs completed successfully:

| Iteration | Time (s) | Node A source reads | Node B peer hits | Node B source reads | Node B checksum errors |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 19.199 | 4 | 4 | 0 | 0 |
| 2 | 18.450 | 4 | 4 | 0 | 0 |
| 3 | 19.794 | 4 | 4 | 0 | 0 |

These measurements are diagnostic for the synthetic fixture and are not paper-performance results.

## Observed real-Qwen validation

A complete privately staged Qwen2.5-72B-Instruct snapshot (48 files, 37 safetensor shards, 145,424,101,606 bytes) was validated on two Linux x86_64 hosts using the fixed public CacheFS image. The model and private manifests were not included in the public artifact.

| Scenario | Result | Peer/source/checksum evidence | Diagnostic time |
| --- | --- | --- | ---: |
| Source-backed Qwen peer read | Full manifest verified on shardless B node | B: 34,704 peer hits, 145,424,101,606 peer bytes, 0 source reads, 0 checksum errors | 213.59 s |
| Broadcast preload | B filled its peer cache after A broadcast preload | B: 34,704 peer-hit delta, 145,424,101,606 cached bytes, 0 source reads, 0 checksum errors | 17.58 s |
| Two-consumer warm burst | Both B consumers verified disjoint model-shard sets concurrently | Consumer 1: 17,160 peer hits / 71,915,225,781 peer bytes; Consumer 2: 17,544 peer hits / 73,508,875,825 peer bytes; both 0 source reads and 0 checksum errors | 112.53 s |

These are two-host synthetic-topology diagnostics using real weights. They are not replications of the paper's 50/100-instance, NFS/object-store, or production performance figures.

## Troubleshooting

- `/dev/fuse` missing: run on a Linux host with FUSE enabled and pass `--privileged --device /dev/fuse` to Docker.
- Image pull failure: verify anonymous access to the fixed image digest and confirm that the registry is reachable.
- Peer hits remain zero: verify unique Serf node names, the configured cache interfaces, node A's advertised IP, and inbound CacheFS TCP `17888` plus Serf TCP/UDP `17999`.
- Interrupted run: remove the named Docker containers printed by the script; unmount any remaining FUSE paths with `fusermount -uz <mount>` or `umount -l <mount>`.

Do not publish actual host IPs, container logs, run directories, or SSH configuration in the public repository.
