#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path

CHUNK_SIZE = 1024 * 1024
FILES = {
    "weights/model-weights.bin": (6 * 1024 * 1024, "model-weights"),
    "weights/tensor-index.bin": (1024 * 1024, "tensor-index"),
    "metadata/model.json": (4096, "metadata"),
}


def write_pattern(path: Path, size: int, seed: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as output:
        offset = 0
        while offset < size:
            block = hashlib.sha256(f"{seed}:{offset}".encode()).digest()
            count = min(CHUNK_SIZE, size - offset)
            output.write((block * ((count // len(block)) + 1))[:count])
            offset += count


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        for chunk in iter(lambda: input_file.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Create deterministic CacheFS AE fixture")
    parser.add_argument("workdir", type=Path)
    args = parser.parse_args()

    source = args.workdir / "source"
    source.mkdir(parents=True, exist_ok=True)
    for relative, (size, seed) in FILES.items():
        write_pattern(source / relative, size, seed)

    manifest = args.workdir / "source.manifest"
    with manifest.open("w") as output:
        for relative in sorted(FILES):
            output.write(f"{sha256(source / relative)}  {relative}\n")


if __name__ == "__main__":
    main()
