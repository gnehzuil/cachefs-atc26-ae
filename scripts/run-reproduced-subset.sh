#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

MODE=loopback
ITERATIONS=3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE=$2; shift 2 ;;
    --iterations) ITERATIONS=$2; shift 2 ;;
    *) echo "Usage: $0 [--mode loopback|multihost] [--iterations N]" >&2; exit 1 ;;
  esac
done

[[ "${MODE}" == loopback || "${MODE}" == multihost ]] || { echo "Unsupported mode: ${MODE}" >&2; exit 1; }
[[ "${ITERATIONS}" =~ ^[1-9][0-9]*$ ]] || { echo "iterations must be a positive integer" >&2; exit 1; }

RUN_DIR="${RUN_DIR:-$(new_run_dir reproduced-${MODE})}"
for iteration in $(seq 1 "${ITERATIONS}"); do
  ITERATION_DIR="${RUN_DIR}/iteration-${iteration}"
  start_ns=$(date +%s%N)
  if [[ "${MODE}" == loopback ]]; then
    RUN_DIR="${ITERATION_DIR}" bash "${SCRIPT_DIR}/run-loopback-functional.sh"
  else
    RUN_DIR="${ITERATION_DIR}" bash "${SCRIPT_DIR}/run-multihost-functional.sh"
  fi
  end_ns=$(date +%s%N)
  printf '%s\n' "$((end_ns - start_ns))" > "${ITERATION_DIR}/elapsed_ns"
done

python3 "${SCRIPT_DIR}/render-results.py" --runs "${RUN_DIR}" --output "${RUN_DIR}/summary.md"
printf 'Run directory: %s\n' "${RUN_DIR}"
