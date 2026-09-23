#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_command docker
require_command python3
require_linux_fuse

RUN_DIR="${RUN_DIR:-$(new_run_dir loopback)}"
mkdir -p "${RUN_DIR}"
python3 "${SCRIPT_DIR}/generate_fixture.py" "${RUN_DIR}"

docker pull "${IMAGE_REF}" >/dev/null
SERF_GROUP="cachefs-ae-loopback-$(basename "${RUN_DIR}")"
docker run --rm --privileged --device /dev/fuse --network host \
  -e SERF_GROUP="${SERF_GROUP}" \
  -v "${RUN_DIR}:/work" \
  -v "${SCRIPT_DIR}/container-loopback.sh:/ae-scripts/container-loopback.sh:ro" \
  --entrypoint /bin/sh "${IMAGE_REF}" /ae-scripts/container-loopback.sh

test -f "${RUN_DIR}/result.json"
printf 'Run directory: %s\n' "${RUN_DIR}"
