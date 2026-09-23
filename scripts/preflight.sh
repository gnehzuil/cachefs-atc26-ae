#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

MODE="${1:---loopback}"
[[ "${MODE}" == "--loopback" || "${MODE}" == "--multihost" ]] || {
  echo "Usage: $0 --loopback|--multihost" >&2
  exit 1
}

check_host() {
  local label=$1
  local command_prefix=${2:-}
  ${command_prefix} 'test "$(uname -s)" = Linux'
  ${command_prefix} 'test -c /dev/fuse'
  ${command_prefix} 'command -v docker >/dev/null'
  ${command_prefix} "docker pull '${IMAGE_REF}' >/dev/null"
  ${command_prefix} "docker image inspect '${IMAGE_REF}' --format '{{index .RepoDigests 0}}' | grep -F '${IMAGE_REF}' >/dev/null"
  ${command_prefix} "docker run --rm --entrypoint /bin/sh '${IMAGE_REF}' -lc 'test -x /usr/bin/cachefs && test -x /usr/bin/fusermount && /usr/bin/cachefs cache --help >/dev/null && command -v sha256sum >/dev/null'"
  echo "PASS ${label}: Linux, Docker, FUSE, image digest, CacheFS CLI, and runtime tools"
}

require_command docker
require_command python3
require_command sha256sum
require_linux_fuse

action_local() { bash -lc "$1"; }
check_host "local host" action_local

if [[ "${MODE}" == "--multihost" ]]; then
  load_hosts
  remote_exec a 'test -c /dev/fuse && command -v docker >/dev/null'
  remote_exec b 'test -c /dev/fuse && command -v docker >/dev/null'
  remote_exec a "docker pull '${IMAGE_REF}' >/dev/null"
  remote_exec b "docker pull '${IMAGE_REF}' >/dev/null"
  remote_exec a "docker image inspect '${IMAGE_REF}' --format '{{index .RepoDigests 0}}' | grep -F '${IMAGE_REF}' >/dev/null"
  remote_exec b "docker image inspect '${IMAGE_REF}' --format '{{index .RepoDigests 0}}' | grep -F '${IMAGE_REF}' >/dev/null"
  remote_exec a "ip route get '${NODE_B_IP}' | grep -F 'dev ${CACHE_NIC_A}' >/dev/null"
  remote_exec b "ip route get '${NODE_A_IP}' | grep -F 'dev ${CACHE_NIC_B}' >/dev/null"
  echo "PASS node A and B: image digest and route interfaces verified"
  echo "Ensure inbound CacheFS TCP ${CACHE_PORT} and Serf TCP/UDP ${SERF_PORT} are permitted between hosts."
fi
