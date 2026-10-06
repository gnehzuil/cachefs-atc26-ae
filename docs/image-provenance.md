# Image Provenance

## Availability and build boundary

The artifact distributes a fixed prebuilt CacheFS image. It does not include a Dockerfile, source-based build context, CacheFS source tree, initialized submodules, or non-public build dependencies. The artifact therefore does not support rebuilding or modifying the CacheFS core from source.

The fixed registry digests, offline archive checksum, image config digest, binary version and checksum, and observed runtime package versions provide the available provenance instead.

## Registry image

| Field | Value |
| --- | --- |
| Discovery tag | `eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs:3.7` |
| Immutable OCI index | `sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7` |
| `linux/amd64` manifest | `sha256:da30a1d55671431a8f1f0bbff0f8445999062207e0bf5785e2854d8cc488289e` |
| `linux/amd64` config | `sha256:1cc8816aefef368d56f926a19e9dff1dacedf283473a583290e47a5c87e331b7` |
| `linux/arm64` manifest | `sha256:e226aa4e29d564dc21482f61dab19e079ad93a553d1b70244d14d11d0cf50bef` |

Anonymous reads of the index, amd64 manifest, and an image blob succeeded without credentials on 2026-10-05. Network reachability may still vary by environment.

## Offline image and CacheFS binary

| Field | Value |
| --- | --- |
| Archive | `dist/cachefs-3.7-amd64.tar.gz` |
| Platform | `linux/amd64` |
| Archive SHA-256 | `3f6fef905bfde8d101162bc620cadcc7deb18044f6d8a4ec182a85dacbaa40c2` |
| Archive config | `sha256:1cc8816aefef368d56f926a19e9dff1dacedf283473a583290e47a5c87e331b7` |
| Loaded tag | `cachefs-ae:3.7` |
| Binary path | `/usr/bin/cachefs` |
| Binary version | `3.7.0+2026-08-21.92c91c7af` |
| Embedded revision | `92c91c7afbb210dea706af3c4fe3b2fa143c45b3` |
| Binary SHA-256 | `225380cd1148bdbf4b7c6f55050a6bff3314122a30c9b50b39cc32d5b5deb4ae` |
| Go toolchain | `go1.26.5 (Red Hat 1.26.5-1.0.2.al8)` |

The registry amd64 manifest and offline archive share the same config digest, tying the tarball to the pinned registry image. `docker save` changes the archive manifest representation, so the local archive manifest digest is not expected to equal the registry child-manifest digest.

## Observed runtime package versions

The image is based on Alibaba Cloud Linux 3.11. The principal runtime packages installed in the fixed image are:

| Package | Observed version |
| --- | --- |
| `alinux-release` | `3.2104.11-1.al8` |
| `fuse` / `fuse-libs` | `2.9.7-19.1.al8` |
| `bc` | `1.07.1-5.2.al8` |
| `curl` | `7.61.1-35.0.2.al8.13` |
| `nmap-ncat` | `7.92-3.0.1.al8` |
| `ca-certificates` | `2024.2.69_v8.0.303-80.0.al8` |
| `iputils` | `20180629-11.0.2.al8` |
| `libibverbs` | `48.0-1.0.1.al8` |
| `ali-rdma-core` | `2601.1-1` |
| `rpm` | `4.14.3-32.0.1.1.al8` |
| `procps-ng` | `3.3.15-14.0.3.al8` |

These are observed contents of the released image, not a standalone image-build recipe. Third-party components retain their respective licenses and package notices inside the image.
