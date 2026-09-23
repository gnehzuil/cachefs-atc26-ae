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
[[ -d "${MODEL_SOURCE_A}" && -f "${MODEL_MANIFEST_A}" && -f "${MODEL_METADATA_A}" ]] || { echo "Private model manifest is missing." >&2; exit 1; }

require_command ssh
require_command scp
load_hosts

MODEL_CACHE_MIB="${MODEL_CACHE_MIB:-184320}"
MODEL_BLOCK_MIB="${MODEL_BLOCK_MIB:-4}"
MODEL_SOURCE_ID="${MODEL_SOURCE_ID:-qwen2.5-72b-instruct-ae}"
PRELOAD_TIMEOUT_SECONDS="${PRELOAD_TIMEOUT_SECONDS:-3600}"
RUN_DIR="${RUN_DIR:-$(new_run_dir qwen-preload-broadcast)}"
RUN_ID="$(basename "${RUN_DIR}")"
REMOTE_RUN="${REMOTE_BASE_DIR}/${RUN_ID}"
CONTAINER_A="cachefs-ae-preload-a-${RUN_ID}"
CONTAINER_B="cachefs-ae-preload-b-${RUN_ID}"
SERF_GROUP="cachefs-ae-${RUN_ID}"
KEEP_RUNS="${KEEP_RUNS:-0}"

q() { printf '%q' "$1"; }
cleanup() {
  remote_exec a "docker rm -f $(q "${CONTAINER_A}") >/dev/null 2>&1 || true" || true
  remote_exec b "docker rm -f $(q "${CONTAINER_B}") >/dev/null 2>&1 || true" || true
  if [[ "${KEEP_RUNS}" != 1 ]]; then
    remote_exec a "rm -rf $(q "${REMOTE_RUN}")" || true
    remote_exec b "rm -rf $(q "${REMOTE_RUN}")" || true
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

mkdir -p "${RUN_DIR}"
cp "${MODEL_MANIFEST_A}" "${RUN_DIR}/model.manifest"
cp "${MODEL_METADATA_A}" "${RUN_DIR}/model.manifest.json"
TARGET_BYTES=$(python3 - "${RUN_DIR}/model.manifest.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))['total_bytes'])
PY
)

for role in a b; do
  remote_exec "${role}" "rm -rf $(q "${REMOTE_RUN}") && mkdir -p $(q "${REMOTE_RUN}")"
  remote_copy "${role}" "${SCRIPT_DIR}/container-node.sh" "${REMOTE_RUN}/"
  remote_exec "${role}" "docker pull $(q "${IMAGE_REF}") >/dev/null"
done
remote_copy b "${RUN_DIR}/model.manifest" "${REMOTE_RUN}/"

remote_exec a "docker run -d --rm --name $(q "${CONTAINER_A}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${MODEL_SOURCE_A}"):/model:ro -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=source-ready -e NODE_NAME=$(q "${RUN_ID}-a") -e CACHE_NIC=$(q "${CACHE_NIC_A}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e LIVENESS_PORT=${NODE_A_LIVENESS_PORT} -e METRICS_PORT=${NODE_A_METRICS_PORT} -e SOURCE_DIR=/model -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e CACHE_SIZE_MIB=${MODEL_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_mount a "${CONTAINER_A}"
remote_exec a "docker exec $(q "${CONTAINER_A}") /usr/bin/cachefs source-ready /work/mount"

remote_exec b "docker run -d --rm --name $(q "${CONTAINER_B}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=sourceless -e NODE_NAME=$(q "${RUN_ID}-b") -e CACHE_NIC=$(q "${CACHE_NIC_B}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e SERF_JOIN=$(q "${NODE_A_IP}:${SERF_PORT}") -e LIVENESS_PORT=${NODE_B_LIVENESS_PORT} -e METRICS_PORT=${NODE_B_METRICS_PORT} -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e SOURCE_PEERMETA=30 -e CACHE_SIZE_MIB=${MODEL_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_mount b "${CONTAINER_B}"
sleep 10

B_SOURCE_BEFORE=$(metric_remote b "${CONTAINER_B}" cachefs_source_reads)
B_REMOTE_BEFORE=$(metric_remote b "${CONTAINER_B}" cachefs_remote_hits)
start_ns=$(date +%s%N)
remote_exec a "docker exec $(q "${CONTAINER_A}") /usr/bin/cachefs preload --broadcast --all /work/mount"

deadline=$(( $(date +%s) + PRELOAD_TIMEOUT_SECONDS ))
while true; do
  B_CACHE_BYTES=$(metric_remote b "${CONTAINER_B}" cachefs_cache_bytes)
  B_REMOTE_BYTES=$(metric_remote b "${CONTAINER_B}" cachefs_remote_hit_bytes)
  B_FLIGHT=$(metric_remote b "${CONTAINER_B}" cachefs_remote_read_flight)
  if (( B_CACHE_BYTES >= TARGET_BYTES && B_REMOTE_BYTES >= TARGET_BYTES && B_FLIGHT == 0 )); then break; fi
  if (( $(date +%s) >= deadline )); then
    echo "Timed out waiting for broadcast preload: cache=${B_CACHE_BYTES}, remote=${B_REMOTE_BYTES}, target=${TARGET_BYTES}, flight=${B_FLIGHT}" >&2
    exit 1
  fi
  sleep 5
done
end_ns=$(date +%s%N)

remote_exec b "docker exec $(q "${CONTAINER_B}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/model.manifest'"
B_SOURCE_AFTER=$(metric_remote b "${CONTAINER_B}" cachefs_source_reads)
B_REMOTE_AFTER=$(metric_remote b "${CONTAINER_B}" cachefs_remote_hits)
B_CHECKSUM=$(metric_remote b "${CONTAINER_B}" cachefs_remote_checksum_error_count)
A_SOURCE=$(metric_remote a "${CONTAINER_A}" cachefs_source_reads)
assert_positive "node A source reads" "${A_SOURCE}"
assert_zero "node B source reads before preload" "${B_SOURCE_BEFORE}"
assert_zero "node B source reads after preload" "${B_SOURCE_AFTER}"
assert_positive "node B broadcast peer-hit delta" "$((B_REMOTE_AFTER - B_REMOTE_BEFORE))"
assert_zero "node B checksum errors" "${B_CHECKSUM}"

remote_exec a "docker exec $(q "${CONTAINER_A}") cat /work/mount/.stats" > "${RUN_DIR}/node-a.stats"
remote_exec b "docker exec $(q "${CONTAINER_B}") cat /work/mount/.stats" > "${RUN_DIR}/node-b.stats"
python3 - "${RUN_DIR}/result.json" "${RUN_DIR}/model.manifest.json" "$((end_ns - start_ns))" "${A_SOURCE}" "${B_SOURCE_AFTER}" "$((B_REMOTE_AFTER - B_REMOTE_BEFORE))" "${B_CHECKSUM}" <<'PY'
import json, sys
from pathlib import Path
meta = json.loads(Path(sys.argv[2]).read_text())
Path(sys.argv[1]).write_text(json.dumps({
  'format': 2, 'scenario': 'real-qwen-broadcast-preload diagnostic only',
  'fixture': {'bytes': meta['total_bytes'], 'files': meta['files'], 'manifest_sha256': meta['manifest_sha256']},
  'broadcast_wall_seconds': int(sys.argv[3]) / 1_000_000_000,
  'node_a': {'source_reads': int(sys.argv[4])},
  'node_b': {'source_reads': int(sys.argv[5]), 'remote_hit_delta': int(sys.argv[6]), 'checksum_errors': int(sys.argv[7])},
}, indent=2, sort_keys=True) + '\n')
PY
printf 'PASS real Qwen broadcast preload\n'
printf 'Run directory: %s\n' "${RUN_DIR}"
