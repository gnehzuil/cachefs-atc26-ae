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

An offline `linux/amd64` tarball is tracked at `dist/cachefs-3.7-amd64.tar.gz` (gzip SHA-256 `3f6fef905bfde8d101162bc620cadcc7deb18044f6d8a4ec182a85dacbaa40c2`) for evaluators who cannot reach the registry. It contains the `linux/amd64` child manifest `sha256:da30a1d55671431a8f1f0bbff0f8445999062207e0bf5785e2854d8cc488289e` of the pinned multi-arch index; `docker load` restores it as `cachefs-ae:3.7`. Use `IMAGE_REF=cachefs-ae:3.7 PULL_IMAGE=0` with the scripts.

Before a public GitHub release, maintainers must re-run `scripts/preflight.sh --loopback`, record the resulting Docker/image metadata, and complete the third-party notice audit for the binary image. Do not update the digest without creating a new public artifact version and repeating validation.
