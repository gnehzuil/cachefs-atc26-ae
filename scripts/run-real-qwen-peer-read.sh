#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

MODEL_CONFIG="${MODEL_CONFIG:-${REPO_ROOT}/config/model.env}"
[[ -f "${MODEL_CONFIG}" ]] || { echo "Missing ${MODEL_CONFIG}; fetch or configure a private model first." >&2; exit 1; }
# shellcheck disable=SC1090
source "${MODEL_CONFIG}"
: "${MODEL_SOURCE_A:?MODEL_SOURCE_A is required}"
: "${MODEL_MANIFEST_A:?MODEL_MANIFEST_A is required}"
: "${MODEL_METADATA_A:?MODEL_METADATA_A is required}"
[[ -d "${MODEL_SOURCE_A}" && -f "${MODEL_MANIFEST_A}" && -f "${MODEL_METADATA_A}" ]] || {
  echo "Private Qwen model or manifest is missing. Run fetch-qwen-modelscope.sh first." >&2
  exit 1
}

require_command ssh
require_command scp
load_hosts

MODEL_CACHE_MIB="${MODEL_CACHE_MIB:-184320}"
MODEL_BLOCK_MIB="${MODEL_BLOCK_MIB:-4}"
MODEL_SOURCE_ID="${MODEL_SOURCE_ID:-qwen2.5-72b-instruct-ae}"
RUN_DIR="${RUN_DIR:-$(new_run_dir real-qwen-peer-read)}"
RUN_ID="$(basename "${RUN_DIR}")"
REMOTE_RUN="${REMOTE_BASE_DIR}/${RUN_ID}"
CONTAINER_A="cachefs-ae-qwen-a-${RUN_ID}"
CONTAINER_B="cachefs-ae-qwen-b-${RUN_ID}"
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

wait_remote_mount() {
  local role=$1 container=$2 attempt
  for attempt in $(seq 1 120); do
    if ! remote_exec "${role}" "docker inspect $(q "${container}") >/dev/null 2>&1"; then
      echo "CacheFS container exited before mounting on node ${role}" >&2
      remote_exec "${role}" "docker logs $(q "${container}")" >&2 || true
      exit 1
    fi
    if remote_exec "${role}" "docker exec $(q "${container}") /bin/sh -c 'grep -qs \" /work/mount \" /proc/mounts'"; then
      return 0
    fi
    sleep 1
  done
  remote_exec "${role}" "docker logs $(q "${container}")" >&2 || true
  echo "CacheFS mount did not become ready on node ${role}" >&2
  exit 1
}

mkdir -p "${RUN_DIR}"
cp "${MODEL_MANIFEST_A}" "${RUN_DIR}/model.manifest"
cp "${MODEL_METADATA_A}" "${RUN_DIR}/model.manifest.json"

for role in a b; do
  remote_exec "${role}" "rm -rf $(q "${REMOTE_RUN}") && mkdir -p $(q "${REMOTE_RUN}")"
  remote_copy "${role}" "${SCRIPT_DIR}/container-node.sh" "${REMOTE_RUN}/"
  remote_exec "${role}" "docker pull $(q "${IMAGE_REF}") >/dev/null"
done
remote_copy a "${RUN_DIR}/model.manifest" "${REMOTE_RUN}/"
remote_copy b "${RUN_DIR}/model.manifest" "${REMOTE_RUN}/"

remote_exec a "docker run -d --name $(q "${CONTAINER_A}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${MODEL_SOURCE_A}"):/model:ro -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=source -e ENABLE_SOURCE_PEERMETA=1 -e SOURCE_PEERMETA=1 -e ENABLE_API_SERVER=1 -e API_SERVER_SOCK=/work/cachefs-api.sock -e NODE_NAME=$(q "${RUN_ID}-a") -e CACHE_NIC=$(q "${CACHE_NIC_A}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e LIVENESS_PORT=${NODE_A_LIVENESS_PORT} -e METRICS_PORT=${NODE_A_METRICS_PORT} -e SOURCE_DIR=/model -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e CACHE_SIZE_MIB=${MODEL_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_remote_mount a "${CONTAINER_A}"

# Static production-style source-backed provider: warm the complete immutable model and publish cached metadata.
remote_exec a "docker exec $(q "${CONTAINER_A}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/model.manifest'"
remote_exec a "docker exec $(q "${CONTAINER_A}") /usr/bin/cachefs meta-ready -s /work/cachefs-api.sock /work/mount"
remote_exec a "docker exec $(q "${CONTAINER_A}") cat /work/mount/.stats" > "${RUN_DIR}/node-a-before-b.stats"

remote_exec b "docker run -d --name $(q "${CONTAINER_B}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e NODE_MODE=sourceless -e NODE_NAME=$(q "${RUN_ID}-b") -e CACHE_NIC=$(q "${CACHE_NIC_B}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e SERF_JOIN=$(q "${NODE_A_IP}:${SERF_PORT}") -e LIVENESS_PORT=${NODE_B_LIVENESS_PORT} -e METRICS_PORT=${NODE_B_METRICS_PORT} -e SOURCE_ID=$(q "${MODEL_SOURCE_ID}") -e SOURCE_PEERMETA=30 -e CACHE_SIZE_MIB=${MODEL_CACHE_MIB} -e BLOCK_SIZE_MIB=${MODEL_BLOCK_MIB} -e PREFETCH_BLOCKS=0 --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_remote_mount b "${CONTAINER_B}"
sleep 10

start_ns=$(date +%s%N)
remote_exec b "docker exec $(q "${CONTAINER_B}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/model.manifest'"
end_ns=$(date +%s%N)

remote_exec a "docker exec $(q "${CONTAINER_A}") cat /work/mount/.stats" > "${RUN_DIR}/node-a-after-b.stats"
remote_exec b "docker exec $(q "${CONTAINER_B}") cat /work/mount/.stats" > "${RUN_DIR}/node-b-after.stats"
remote_exec a "docker logs $(q "${CONTAINER_A}")" > "${RUN_DIR}/node-a.log" || true
remote_exec b "docker logs $(q "${CONTAINER_B}")" > "${RUN_DIR}/node-b.log" || true

SOURCE_A=$(metric_value cachefs_source_reads "${RUN_DIR}/node-a-before-b.stats")
SOURCE_B=$(metric_value cachefs_source_reads "${RUN_DIR}/node-b-after.stats")
REMOTE_B=$(metric_value cachefs_remote_hits "${RUN_DIR}/node-b-after.stats")
CHECKSUM_B=$(metric_value cachefs_remote_checksum_error_count "${RUN_DIR}/node-b-after.stats")
assert_positive "node A source reads after source-ready" "${SOURCE_A}"
assert_zero "node B source reads" "${SOURCE_B}"
assert_positive "node B peer hits" "${REMOTE_B}"
assert_zero "node B checksum errors" "${CHECKSUM_B}"

python3 - "${RUN_DIR}/result.json" "${RUN_DIR}/model.manifest.json" "$((end_ns - start_ns))" "${SOURCE_A}" "${SOURCE_B}" "${REMOTE_B}" "${CHECKSUM_B}" <<'PY'
import json
import sys
from pathlib import Path

meta = json.loads(Path(sys.argv[2]).read_text())
result = {
    "format": 2,
    "scope": "real-qwen-fuse-peer-read diagnostic only",
    "fixture": {"files": meta["files"], "bytes": meta["total_bytes"], "manifest_sha256": meta["manifest_sha256"]},
    "wall_seconds": int(sys.argv[3]) / 1_000_000_000,
    "node_a": {"source_reads": int(sys.argv[4])},
    "node_b": {"source_reads": int(sys.argv[5]), "remote_hits": int(sys.argv[6]), "checksum_errors": int(sys.argv[7])},
}
Path(sys.argv[1]).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
PY
printf 'PASS real Qwen source-backed and peer-read manifest validation\n'
printf 'Run directory: %s\n' "${RUN_DIR}"
