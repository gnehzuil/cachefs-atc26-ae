#!/usr/bin/env python3
import argparse
import csv
import json
import statistics
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = []
    for result_path in sorted(args.runs.glob("iteration-*/result.json")):
        data = json.loads(result_path.read_text())
        elapsed_path = result_path.with_name("elapsed_ns")
        rows.append({
            "iteration": result_path.parent.name[len("iteration-"):],
            "elapsed_seconds": int(elapsed_path.read_text().strip()) / 1_000_000_000,
            "node_a_source_reads": data["node_a"]["source_reads"],
            "node_b_peer_hits": data["node_b"]["remote_hits"],
            "node_b_source_reads": data["node_b"]["source_reads"],
            "node_b_checksum_errors": data["node_b"]["checksum_errors"],
        })

    if not rows:
        raise SystemExit("No iteration result.json files found")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    csv_path = args.output.with_suffix(".csv")
    with csv_path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    durations = [row["elapsed_seconds"] for row in rows]
    lines = [
        "# CacheFS AE Repeated Peer-Read Summary",
        "",
        "This synthetic-data result validates functional source fill and peer-served reads only.",
        "It is not a reproduction of the paper's production-scale performance figures.",
        "",
        "| Iteration | Time (s) | A source reads | B peer hits | B source reads | B checksum errors |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['iteration']} | {row['elapsed_seconds']:.3f} | {row['node_a_source_reads']} | "
            f"{row['node_b_peer_hits']} | {row['node_b_source_reads']} | {row['node_b_checksum_errors']} |"
        )
    lines.extend([
        "",
        "## Summary",
        "",
        f"- Runs: {len(rows)}",
        f"- Time: {min(durations):.3f}s min, {statistics.median(durations):.3f}s median, {max(durations):.3f}s max",
        f"- Minimum node-B peer hits: {min(row['node_b_peer_hits'] for row in rows)}",
        f"- Maximum node-B checksum errors: {max(row['node_b_checksum_errors'] for row in rows)}",
    ])
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
