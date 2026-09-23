#!/usr/bin/env python3
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Split a SHA-256 manifest across consumers")
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--consumers", type=int, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    if args.consumers < 1:
        raise SystemExit("consumers must be positive")

    lines = [line for line in args.manifest.read_text().splitlines() if line.strip()]
    if len(lines) < args.consumers:
        raise SystemExit("manifest has fewer files than consumers")
    partitions = [[] for _ in range(args.consumers)]
    for index, line in enumerate(lines):
        partitions[index % args.consumers].append(line)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, entries in enumerate(partitions, 1):
        (args.output_dir / f"consumer-{index}.manifest").write_text("\n".join(entries) + "\n")


if __name__ == "__main__":
    main()
