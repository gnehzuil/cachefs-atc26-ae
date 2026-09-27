#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_REF="${IMAGE_REF:-eci-nydus-registry.cn-hangzhou.cr.aliyuncs.com/kangaroo/cachefs@sha256:0ae0aa9be70ed615159b80dd32422079540bad6c6dac3be7a7648eb28e72bde7}"
# Set PULL_IMAGE=0 when the image is already loaded locally (e.g. via `docker load`
# of the offline tarball) and the registry is unreachable; scripts then skip pulls.
readonly PULL_IMAGE="${PULL_IMAGE:-1}"
readonly CACHE_PORT=17888
readonly SERF_PORT=17999
readonly NODE_A_METRICS_PORT=19678
readonly NODE_B_METRICS_PORT=19679
readonly NODE_A_LIVENESS_PORT=19555
readonly NODE_B_LIVENESS_PORT=19556

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNS_DIR="${RUNS_DIR:-${REPO_ROOT}/runs}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_linux_fuse() {
  [[ "$(uname -s)" == "Linux" ]] || {
    echo "This artifact requires Linux." >&2
    exit 1
  }
  [[ -c /dev/fuse ]] || {
    echo "Missing /dev/fuse. Enable FUSE and run Docker with --device /dev/fuse." >&2
    exit 1
  }
}

new_run_dir() {
  local prefix=$1
  local run_dir="${RUNS_DIR}/${prefix}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mkdir -p "${run_dir}"
  printf '%s\n' "${run_dir}"
}

metric_value() {
  local metric=$1
  local stats=$2
  awk -v metric="${metric}" '$1 == metric { print $2; found=1; exit } END { if (!found) exit 1 }' "${stats}"
}

assert_positive() {
  local label=$1
  local value=$2
  (( value > 0 )) || {
    echo "Expected ${label} > 0, got ${value}" >&2
    exit 1
  }
}

assert_zero() {
  local label=$1
  local value=$2
  (( value == 0 )) || {
    echo "Expected ${label} == 0, got ${value}" >&2
    exit 1
  }
}

load_hosts() {
  local config_file="${HOSTS_CONFIG:-${REPO_ROOT}/config/hosts.env}"
  [[ -f "${config_file}" ]] || {
    echo "Missing ${config_file}; copy config/hosts.example.env and edit it locally." >&2
    exit 1
  }
  # shellcheck disable=SC1090
  source "${config_file}"
  : "${NODE_A_HOST:?NODE_A_HOST is required}"
  : "${NODE_B_HOST:?NODE_B_HOST is required}"
  : "${NODE_A_IP:?NODE_A_IP is required}"
  : "${NODE_B_IP:?NODE_B_IP is required}"
  : "${CACHE_NIC_A:?CACHE_NIC_A is required}"
  : "${CACHE_NIC_B:?CACHE_NIC_B is required}"
  SSH_USER="${SSH_USER:-root}"
  SSH_PORT="${SSH_PORT:-22}"
  NODE_A_SSH_PORT="${NODE_A_SSH_PORT:-${SSH_PORT}}"
  NODE_B_SSH_PORT="${NODE_B_SSH_PORT:-${SSH_PORT}}"
  REMOTE_BASE_DIR="${REMOTE_BASE_DIR:-/tmp/cachefs-atc26-ae}"
}

remote_target() {
  local role=$1
  case "${role}" in
    a) printf '%s@%s' "${SSH_USER}" "${NODE_A_HOST}" ;;
    b) printf '%s@%s' "${SSH_USER}" "${NODE_B_HOST}" ;;
    *) echo "Unknown node role: ${role}" >&2; exit 1 ;;
  esac
}

remote_port() {
  case "$1" in
    a) printf '%s' "${NODE_A_SSH_PORT}" ;;
    b) printf '%s' "${NODE_B_SSH_PORT}" ;;
    *) echo "Unknown node role: $1" >&2; exit 1 ;;
  esac
}

remote_exec() {
  local role=$1
  shift
  ssh -o BatchMode=yes -p "$(remote_port "${role}")" "$(remote_target "${role}")" "$@"
}

remote_copy() {
  local role=$1
  local source=$2
  local destination=$3
  scp -o BatchMode=yes -P "$(remote_port "${role}")" -pr "${source}" "$(remote_target "${role}"):${destination}"
}
