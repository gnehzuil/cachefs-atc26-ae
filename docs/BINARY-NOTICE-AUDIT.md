# Binary Image Notice and SBOM Audit

The CacheFS binary image is author-approved for Apache-2.0 public distribution. This document is the release gate for the complete notice/SBOM audit; do not mark it complete by inference from the source-tree Apache license alone.

## Fixed artifact image

- Reference: `eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs@sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7`
- Observed version: `3.7.0+2026-08-21.92c91c7af`
- Public license: Apache-2.0, confirmed by the artifact authors.

## Required release evidence

- [ ] Final image digest and base-image digests recorded.
- [ ] Release-specific SBOM generated from the final image.
- [ ] Third-party notices included or linked for every component represented in the SBOM.
- [ ] Required Apache, MIT, BSD, Boost, MPL, LGPL-with-exception, patent, and attribution texts reviewed against actual linked/shipped components.
- [ ] Public redistribution authorization for every non-source component recorded.
- [ ] No private adapter source, model data, credentials, or internal registry layer is included.

Known source-tree materials useful for the audit include the CacheFS Apache license, gocryptfs MIT license, and Yalanting Apache license/NOTICE. They are evidence inputs only; final image contents must be audited directly.
