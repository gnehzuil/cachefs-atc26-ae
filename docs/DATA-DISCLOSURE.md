# Data Disclosure and Release Boundary

## Public release allowlist

The public artifact release may contain only:

- documentation, Apache-2.0 `LICENSE`, `NOTICE`, provenance, and release metadata;
- Bash/Python orchestration and verification scripts for the fixed public CacheFS binary image;
- example configuration files with placeholders only;
- synthetic smoke-test generator code; and
- the explicitly authorized `dist/cachefs-3.7-amd64.tar.gz` offline image, only when its SHA-256 matches the fixed value checked by `scripts/audit-public-release.sh`.

## Explicitly excluded

Do not publish, attach to a GitHub release, place in an issue, or upload to the artifact venue:

- CacheFS implementation source, non-public build dependencies, private adapters, or internal build logs;
- Qwen model shards, model configuration/tokenizer files, model manifests, hashes tied to private paths, access tokens, or model caches;
- production traces, object-store/NFS endpoints, model registry URLs beyond the documented public ModelScope acquisition page, or credentials;
- real hostnames, IP addresses, SSH ports/users/keys, raw Docker/CacheFS logs, run directories, network topology, or GPU inventory;
- Docker image exports/layers other than the single allowlisted CacheFS offline image.

## Evaluator-provided model data

The default Reproduced path asks each evaluator to obtain Qwen2.5-72B-Instruct directly from ModelScope after reviewing and accepting the model license. The model resides only in evaluator-controlled private staging. The public repository provides no model bytes and does not redistribute the model.

## External network and privilege disclosure

The scripts may contact the public CacheFS registry and ModelScope when the evaluator invokes model download. Docker runs CacheFS with `--privileged`, `/dev/fuse`, and host networking. Evaluators should use isolated hosts and should not run the scripts on systems containing sensitive data.

## Release procedure

Before a public tag/release:

1. Run `scripts/audit-public-release.sh` against a clean export of the repository.
2. Verify no ignored private config, runs, models, unapproved binaries, logs, or release assets are included.
3. Review `LICENSE`, `NOTICE`, and `docs/image-provenance.md` for the released binary image.
4. Record public image digest, artifact tag, release archive checksum, and audit date.
5. Confirm the public README/home page and support contact are stable.
