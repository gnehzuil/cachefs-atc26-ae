#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

MODEL_CONFIG="${MODEL_CONFIG:-${REPO_ROOT}/config/model.env}"
[[ -f "${MODEL_CONFIG}" ]] || { echo "Missing ${MODEL_CONFIG}" >&2; exit 1; }
# shellcheck disable=SC1090
source "${MODEL_CONFIG}"
: "${MODEL_SOURCE_A:?MODEL_SOURCE_A is required}"
: "${MODEL_MANIFEST_A:?MODEL_MANIFEST_A is required}"
: "${MODEL_METADATA_A:?MODEL_METADATA_A is required}"
[[ -d "${MODEL_SOURCE_A}" && -f "${MODEL_MANIFEST_A}" && -f "${MODEL_METADATA_A}" ]] || { echo "Private model or manifest is missing." >&2; exit 1; }

CONSUMERS="${CONSUMERS:-2}"
[[ "${CONSUMERS}" =~ ^[2-4]$ ]] || { echo "CONSUMERS must be 2, 3, or 4" >&2; exit 1; }
require_command ssh
require_command scp
require_command python3
load_hosts

MODEL_CACHE_MIB="${MODEL_CACHE_MIB:-184320}"
B_CACHE_MIB="${B_CACHE_MIB:-65536}"
MODEL_BLOCK_MIB="${MODEL_BLOCK_MIB:-4}"
MODEL_SOURCE_ID="${MODEL_SOURCE_ID:-qwen2.5-72b-instruct-ae}"
RUN_DIR="${RUN_DIR:-$(new_run_dir qwen-warm-burst)}"
RUN_ID="$(basename "${RUN_DIR}")"
REMOTE_ROOT="${REMOTE_BASE_DIR}/${RUN_ID}"
REMOTE_A="${REMOTE_ROOT}/a"
REMOTE_B="${REMOTE_ROOT}/b"
CONTAINER_A="cachefs-ae-burst-a-${RUN_ID}"
SERF_GROUP="cachefs-ae-${RUN_ID}"
KEEP_RUNS="${KEEP_RUNS:-0}"
B_CONTAINERS=()

q() { printf '%q' "$1"; }
cleanup() {
  remote_exec a "docker rm -f $(q "${CONTAINER_A}") >/dev/null 2>&1 || true" || true
  for container in "${B_CONTAINERS[@]:-}"; do
    remote_exec b "docker rm -f $(q "${container}") >/dev/null 2>&1 || true" || true
  done
  if [[ "${KEEP_RUNS}" != 1 ]]; then
    remote_exec a "rm -rf $(q "${REMOTE_A}")" || true
    remote_exec b "rm -rf $(q "${REMOTE_B}")" || true
  fi
}
trap cleanup EXIT INT TERM

wait_mount() {
  local role=$1 container=$2 attempt
  for attempt in $(seq 1 120); do
    if remote_exec "${role}" "docker exec $(q "${container}") /bin/sh -c 'grep -qs \" /work/mount \" /proc/mounts'"; then return 0; fi
    sleep 1
  done
  remote_exec "${role}" "docker logs $(q "${container}")" >&2 || true
  echo "Mount did not become ready on ${role}" >&2
  exit 1
}
metric_remote() {
  local role=$1 container=$2 metric=$3
  remote_exec "${role}" "docker exec $(q "${container}") /bin/sh -c \"awk -v key='${metric}' '\\\$1 == key {print \\\$2; found=1; exit} END {if (!found) exit 1}' /work/mount/.stats\""
}

mkdir -p "${RUN_DIR}/partitions"
cp "${MODEL_MANIFEST_A}" "${RUN_DIR}/model.manifest"
cp "${MODEL_METADATA_A}" "${RUN_DIR}/model.manifest.json"
python3 "${SCRIPT_DIR}/split-manifest.py" "${RUN_DIR}/model.manifest" --consumers "${CONSUMERS}" --output-dir "${RUN_DIR}/partitions"

remote_exec a "rm -rf $(q "${REMOTE_A}") && mkdir -p $(q "${REMOTE_A}")"
remote_exec b "rm -rf $(q "${REMOTE_B}") && mkdir -p $(q "${REMOTE_B}")"
remote_copy a "${SCRIPT_DIR}/container-node.sh" "${REMOTE_A}/"
remote_copy b "${SCRIPT_DIR}/container-node.sh" "${REMOTE_B}/"
remote_exec a "docker pull $(q "${IMAGE_REF}") >/dev/null"
remote_exec b "docker pull $(q "${IMAGE_REF}") >/dev/null"

remote_exec a "docker run -d --rm --name $(q "${CONTAINER_A}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_A}"):/work -v $(q "${MODEL_SOURCE_A}"):/model:ro -v $(q "${REMOTE_A}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=source-ready -e NODE_NAME=$(q "${RUN_ID}-a") -e CACHE_NIC=$(q "${CACHE_NIC_A}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e LIVENESS_PORT=${NODE_A_LIVENESS_PORT} -e METRICS_PORT=${NODE_A_METRICS_PORT} -e SOURCE_DIR=/model -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e CACHE_SIZE_MIB=${MODEL_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_mount a "${CONTAINER_A}"
remote_exec a "docker exec $(q "${CONTAINER_A}") /usr/bin/cachefs source-ready /work/mount"
A_SOURCE_BYTES_BEFORE=$(metric_remote a "${CONTAINER_A}" cachefs_source_read_bytes)

for i in $(seq 1 "${CONSUMERS}"); do
  work="${REMOTE_B}/consumer-${i}"
  container="cachefs-ae-burst-b${i}-${RUN_ID}"
  B_CONTAINERS+=("${container}")
  remote_exec b "mkdir -p $(q "${work}")"
  remote_copy b "${RUN_DIR}/partitions/consumer-${i}.manifest" "${work}/"
  cache_port=$((18000 + i)); serf_port=$((18100 + i)); live_port=$((19000 + i)); metrics_port=$((19100 + i))
  remote_exec b "docker run -d --rm --name $(q "${container}") --privileged --device /dev/fuse --network host -v $(q "${work}"):/work -v $(q "${REMOTE_B}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=sourceless -e NODE_NAME=$(q "${RUN_ID}-b${i}") -e CACHE_NIC=$(q "${CACHE_NIC_B}") -e CACHE_PORT=${cache_port} -e SERF_PORT=${serf_port} -e SERF_GROUP=$(q "${SERF_GROUP}") -e SERF_JOIN=$(q "${NODE_A_IP}:${SERF_PORT}") -e LIVENESS_PORT=${live_port} -e METRICS_PORT=${metrics_port} -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e SOURCE_PEERMETA=30 -e CACHE_SIZE_MIB=${B_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
  wait_mount b "${container}"
done
sleep 10

start_ns=$(date +%s%N)
pids=()
for i in $(seq 1 "${CONSUMERS}"); do
  container="${B_CONTAINERS[$((i-1))]}"
  ( remote_exec b "docker exec $(q "${container}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/consumer-${i}.manifest'" > "${RUN_DIR}/consumer-${i}.verify.log" 2>&1 ) &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "${pid}"; done
end_ns=$(date +%s%N)
A_SOURCE_BYTES_AFTER=$(metric_remote a "${CONTAINER_A}" cachefs_source_read_bytes)

for i in $(seq 1 "${CONSUMERS}"); do
  container="${B_CONTAINERS[$((i-1))]}"
  remote_exec b "docker exec $(q "${container}") cat /work/mount/.stats" > "${RUN_DIR}/consumer-${i}.stats"
  source_reads=$(metric_value cachefs_source_reads "${RUN_DIR}/consumer-${i}.stats")
  remote_hits=$(metric_value cachefs_remote_hits "${RUN_DIR}/consumer-${i}.stats")
  remote_bytes=$(metric_value cachefs_remote_hit_bytes "${RUN_DIR}/consumer-${i}.stats")
  checksum_errors=$(metric_value cachefs_remote_checksum_error_count "${RUN_DIR}/consumer-${i}.stats")
  assert_zero "consumer ${i} source reads" "${source_reads}"
  assert_positive "consumer ${i} peer hits" "${remote_hits}"
  assert_positive "consumer ${i} peer bytes" "${remote_bytes}"
  assert_zero "consumer ${i} checksum errors" "${checksum_errors}"
done
assert_zero "provider source bytes during warm burst" "$((A_SOURCE_BYTES_AFTER - A_SOURCE_BYTES_BEFORE))"

python3 - "${RUN_DIR}/result.json" "${RUN_DIR}/model.manifest.json" "$((end_ns - start_ns))" "${CONSUMERS}" "${RUN_DIR}" <<'PY'
import json, sys
from pathlib import Path
out, meta_path, elapsed, consumers, run_dir = map(Path, [sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]])
meta = json.loads(meta_path.read_text())
rows = []
for i in range(1, int(str(consumers)) + 1):
    metrics = {}
    for line in (run_dir / f"consumer-{i}.stats").read_text().splitlines():
        fields = line.split()
        if len(fields) == 2:
            metrics[fields[0]] = fields[1]
    rows.append({"consumer": i, "source_reads": int(metrics["cachefs_source_reads"]), "remote_hits": int(metrics["cachefs_remote_hits"]), "remote_hit_bytes": int(metrics["cachefs_remote_hit_bytes"]), "checksum_errors": int(metrics["cachefs_remote_checksum_error_count"])})
out.write_text(json.dumps({"format": 2, "scenario": "real-qwen-warm-burst diagnostic only", "fixture": {"bytes": meta["total_bytes"], "files": meta["files"], "manifest_sha256": meta["manifest_sha256"]}, "consumers": rows, "burst_wall_seconds": int(str(elapsed)) / 1_000_000_000}, indent=2, sort_keys=True) + "\n")
PY
printf 'PASS real Qwen warm burst with %s consumers\n' "${CONSUMERS}"
printf 'Run directory: %s\n' "${RUN_DIR}"
