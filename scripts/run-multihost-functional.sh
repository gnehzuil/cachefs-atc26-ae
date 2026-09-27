#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_command python3
require_command sha256sum
require_command ssh
require_command scp
load_hosts

RUN_DIR="${RUN_DIR:-$(new_run_dir multihost)}"
RUN_ID="$(basename "${RUN_DIR}")"
REMOTE_RUN="${REMOTE_BASE_DIR}/${RUN_ID}"
CONTAINER_A="cachefs-ae-a-${RUN_ID}"
CONTAINER_B="cachefs-ae-b-${RUN_ID}"
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

mkdir -p "${RUN_DIR}"
python3 "${SCRIPT_DIR}/generate_fixture.py" "${RUN_DIR}"

for role in a b; do
  remote_exec "${role}" "rm -rf $(q "${REMOTE_RUN}") && mkdir -p $(q "${REMOTE_RUN}")"
  remote_copy "${role}" "${RUN_DIR}/source" "${REMOTE_RUN}/"
  remote_copy "${role}" "${RUN_DIR}/source.manifest" "${REMOTE_RUN}/"
  remote_copy "${role}" "${SCRIPT_DIR}/container-node.sh" "${REMOTE_RUN}/"
  if [[ "${PULL_IMAGE}" == "1" ]]; then
    remote_exec "${role}" "docker pull $(q "${IMAGE_REF}") >/dev/null"
  fi
done

remote_exec a "docker run -d --rm --name $(q "${CONTAINER_A}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e ROLE=node-a -e NODE_NAME=$(q "${RUN_ID}-a") -e CACHE_NIC=$(q "${CACHE_NIC_A}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e LIVENESS_PORT=${NODE_A_LIVENESS_PORT} -e METRICS_PORT=${NODE_A_METRICS_PORT} --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"

wait_remote_mount() {
  local role=$1
  local container=$2
  local attempt
  for attempt in $(seq 1 30); do
    if remote_exec "${role}" "docker exec $(q "${container}") /bin/sh -c 'grep -qs \" /work/mount \" /proc/mounts'"; then
      return 0
    fi
    sleep 1
  done
  remote_exec "${role}" "docker logs $(q "${container}")" >&2 || true
  echo "CacheFS mount did not become ready on node ${role}" >&2
  exit 1
}

wait_remote_mount a "${CONTAINER_A}"
remote_exec a "docker exec $(q "${CONTAINER_A}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/source.manifest'"

remote_exec b "docker run -d --rm --name $(q "${CONTAINER_B}") --privileged --device /dev/fuse --network host -v $(q "${REMOTE_RUN}"):/work -v $(q "${REMOTE_RUN}/container-node.sh"):/ae-scripts/container-node.sh:ro -e ROLE=node-b -e NODE_NAME=$(q "${RUN_ID}-b") -e CACHE_NIC=$(q "${CACHE_NIC_B}") -e CACHE_PORT=${CACHE_PORT} -e SERF_PORT=${SERF_PORT} -e SERF_GROUP=$(q "${SERF_GROUP}") -e SERF_JOIN=$(q "${NODE_A_IP}:${SERF_PORT}") -e LIVENESS_PORT=${NODE_B_LIVENESS_PORT} -e METRICS_PORT=${NODE_B_METRICS_PORT} --entrypoint /bin/sh $(q "${IMAGE_REF}") /ae-scripts/container-node.sh >/dev/null"
wait_remote_mount b "${CONTAINER_B}"
sleep 5
remote_exec b "docker exec $(q "${CONTAINER_B}") /bin/sh -c 'cd /work/mount && sha256sum -c /work/source.manifest'"

remote_exec a "docker exec $(q "${CONTAINER_A}") cat /work/mount/.stats" > "${RUN_DIR}/node-a.stats"
remote_exec b "docker exec $(q "${CONTAINER_B}") cat /work/mount/.stats" > "${RUN_DIR}/node-b.stats"
remote_exec a "docker logs $(q "${CONTAINER_A}")" > "${RUN_DIR}/node-a.log" || true
remote_exec b "docker logs $(q "${CONTAINER_B}")" > "${RUN_DIR}/node-b.log" || true

SOURCE_A=$(metric_value cachefs_source_reads "${RUN_DIR}/node-a.stats")
REMOTE_A=$(metric_value cachefs_remote_hits "${RUN_DIR}/node-a.stats")
SOURCE_B=$(metric_value cachefs_source_reads "${RUN_DIR}/node-b.stats")
REMOTE_B=$(metric_value cachefs_remote_hits "${RUN_DIR}/node-b.stats")
CHECKSUM_B=$(metric_value cachefs_remote_checksum_error_count "${RUN_DIR}/node-b.stats")
assert_positive "node A source reads" "${SOURCE_A}"
assert_zero "node A remote hits before node B reads" "${REMOTE_A}"
assert_positive "node B peer hits" "${REMOTE_B}"
assert_zero "node B source reads" "${SOURCE_B}"
assert_zero "node B checksum errors" "${CHECKSUM_B}"

printf '{\n  "format": 1,\n  "scenario": "multihost-two-node-peer-read",\n  "node_a": {"source_reads": %s, "remote_hits": %s},\n  "node_b": {"source_reads": %s, "remote_hits": %s, "checksum_errors": %s}\n}\n' \
  "${SOURCE_A}" "${REMOTE_A}" "${SOURCE_B}" "${REMOTE_B}" "${CHECKSUM_B}" > "${RUN_DIR}/result.json"
printf 'PASS multihost source fill and peer read\n'
printf 'Run directory: %s\n' "${RUN_DIR}"
