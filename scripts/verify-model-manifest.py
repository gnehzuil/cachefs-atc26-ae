#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path

CHUNK = 1024 * 1024
REQUIRED = {"config.json"}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(CHUNK), b""):
            value.update(block)
    return value.hexdigest()


def collect(root: Path):
    files = []
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
        relative = path.relative_to(root).as_posix()
        if relative.startswith(".cachefs-ae-"):
            continue
        files.append({"path": relative, "bytes": path.stat().st_size, "sha256": digest(path)})
    return files


def main():
    parser = argparse.ArgumentParser(description="Create a private Qwen model SHA-256 manifest")
    parser.add_argument("model_dir", type=Path)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--expected-shards", type=int, default=37)
    args = parser.parse_args()

    root = args.model_dir.resolve()
    if not root.is_dir():
        raise SystemExit(f"Model directory does not exist: {root}")
    files = collect(root)
    paths = {entry["path"] for entry in files}
    missing = REQUIRED - paths
    if missing:
        raise SystemExit(f"Missing required model files: {', '.join(sorted(missing))}")
    shards = [entry for entry in files if entry["path"].endswith(".safetensors")]
    if len(shards) != args.expected_shards:
        raise SystemExit(f"Expected {args.expected_shards} safetensors shards, found {len(shards)}")
    if not any("tokenizer" in entry["path"] for entry in files):
        raise SystemExit("Missing tokenizer-related file")

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.manifest.open("w") as output:
        for entry in files:
            output.write(f"{entry['sha256']}  {entry['path']}\n")

    total = sum(entry["bytes"] for entry in files)
    args.metadata.parent.mkdir(parents=True, exist_ok=True)
    args.metadata.write_text(json.dumps({
        "format": 1,
        "model_dir_name": root.name,
        "files": len(files),
        "safetensors_shards": len(shards),
        "total_bytes": total,
        "manifest_sha256": digest(args.manifest),
    }, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
