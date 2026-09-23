# Image Provenance

| Field | Value |
| --- | --- |
| Discovery tag | `eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs:3.7` |
| Immutable reference | `eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs@sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7` |
| Observed platform | Linux x86_64 |
| Observed CacheFS version | `3.7.0+2026-08-21.92c91c7af` |
| Runtime binary | `/usr/bin/cachefs` |
| FUSE helper | `/usr/bin/fusermount` |
| Public distribution license | Apache-2.0 |

The tag is not used by the scripts because tags are mutable. Every script pulls and runs the immutable digest reference.

Before a public GitHub release, maintainers must re-run `scripts/preflight.sh --loopback`, record the resulting Docker/image metadata, and complete the third-party notice audit for the binary image. Do not update the digest without creating a new public artifact version and repeating validation.
