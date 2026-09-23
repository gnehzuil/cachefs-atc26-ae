# Data Disclosure and Release Boundary

## Public release allowlist

The public artifact release may contain only:

- Markdown documentation, Apache-2.0 `LICENSE`, `NOTICE`, and release metadata;
- Bash/Python orchestration scripts that pull the fixed public CacheFS binary image;
- example configuration files with placeholders only;
- synthetic smoke-test generator code.

## Explicitly excluded

Do not publish, attach to a GitHub release, place in an issue, or upload to the artifact venue:

- CacheFS implementation source, build dependencies, private adapters, SBOM inputs, or internal build logs;
- Qwen model shards, model configuration/tokenizer files, model manifests, hashes tied to private paths, access tokens, or model caches;
- production traces, object-store/NFS endpoints, model registry URLs beyond the documented public ModelScope acquisition page, or credentials;
- real hostnames, IP addresses, SSH ports/users/keys, raw Docker/CacheFS logs, run directories, network topology, or GPU inventory;
- Docker image exports/layers or private SGLang images.

## Evaluator-provided model data

The default Reproduced path asks each evaluator to obtain Qwen2.5-72B-Instruct directly from ModelScope after reviewing and accepting the model license. The model resides only in evaluator-controlled private staging. The public repository provides no model bytes and does not redistribute the model.

## External network and privilege disclosure

The scripts may contact the public CacheFS registry, ModelScope (only when the evaluator invokes model download), and optionally an official SGLang registry. Docker runs CacheFS with `--privileged`, `/dev/fuse`, and host networking. Evaluators should use isolated hosts and should not run the scripts on systems containing sensitive data.

## Release procedure

Before a public tag/release:

1. Run `scripts/audit-public-release.sh` against a clean export of the repository.
2. Verify no ignored private config, runs, models, binaries, logs, or release assets are included.
3. Review `docs/BINARY-NOTICE-AUDIT.md` and complete all third-party notice/SBOM entries for the released binary image.
4. Record public image digest, artifact tag, release archive checksum, and audit date.
5. Confirm the public README/home page and support contact are stable.
