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

## Troubleshooting

- `/dev/fuse` missing: run on a Linux host with FUSE enabled and pass `--privileged --device /dev/fuse` to Docker.
- Image pull failure: verify anonymous access to the fixed image digest and confirm that the registry is reachable.
- Peer hits remain zero: verify unique Serf node names, the configured cache interfaces, node A's advertised IP, and inbound CacheFS TCP `17888` plus Serf TCP/UDP `17999`.
- Interrupted run: remove the named Docker containers printed by the script; unmount any remaining FUSE paths with `fusermount -uz <mount>` or `umount -l <mount>`.

Do not publish actual host IPs, container logs, run directories, or SSH configuration in the public repository.
