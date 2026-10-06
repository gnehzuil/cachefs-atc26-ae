#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

MODEL_CONFIG="${MODEL_CONFIG:-${REPO_ROOT}/config/model.env}"
[[ -f "${MODEL_CONFIG}" ]] || { echo "Missing ${MODEL_CONFIG}; copy config/model.example.env and edit it privately." >&2; exit 1; }
# shellcheck disable=SC1090
source "${MODEL_CONFIG}"
: "${MODEL_SOURCE_A:?MODEL_SOURCE_A is required}"
: "${MODEL_MANIFEST_A:?MODEL_MANIFEST_A is required}"
: "${MODEL_METADATA_A:?MODEL_METADATA_A is required}"
: "${I_ACCEPT_MODEL_LICENSE:?Set I_ACCEPT_MODEL_LICENSE=1 after accepting the Qwen license.}"
[[ "${I_ACCEPT_MODEL_LICENSE}" == 1 ]] || { echo "Model license has not been accepted." >&2; exit 1; }

MODEL_ID="${MODEL_ID:-Qwen/Qwen2.5-72B-Instruct}"
: "${MODEL_REVISION:?MODEL_REVISION must be an immutable ModelScope revision}"
MODELSCOPE_TOOLS_IMAGE="${MODELSCOPE_TOOLS_IMAGE:-python@sha256:31dd4d9529d02d7436659061cb7564cd4733fc90e5e152709a942d53382ec8d0}"
MODELSCOPE_VERSION="${MODELSCOPE_VERSION:-1.40.1}"
EXPECTED_SAFETENSOR_SHARDS="${EXPECTED_SAFETENSOR_SHARDS:-37}"

parent="$(dirname "${MODEL_SOURCE_A}")"
mkdir -p "${parent}" "$(dirname "${MODEL_MANIFEST_A}")" "$(dirname "${MODEL_METADATA_A}")"

docker pull "${MODELSCOPE_TOOLS_IMAGE}" >/dev/null
args=(modelscope download "${MODEL_ID}" --revision "${MODEL_REVISION}" --local-dir "/models/$(basename "${MODEL_SOURCE_A}")" --max-workers 8)
if [[ -n "${MODELSCOPE_TOKEN:-}" ]]; then
  args=(modelscope --token "${MODELSCOPE_TOKEN}" download "${MODEL_ID}" --revision "${MODEL_REVISION}" --local-dir "/models/$(basename "${MODEL_SOURCE_A}")" --max-workers 8)
fi

docker run --rm -e PIP_NO_CACHE_DIR=1 -v "${parent}:/models" "${MODELSCOPE_TOOLS_IMAGE}" \
  sh -lc "pip install --disable-pip-version-check modelscope==${MODELSCOPE_VERSION} >/dev/null && $(printf '%q ' "${args[@]}")"

python3 "${SCRIPT_DIR}/verify-model-manifest.py" "${MODEL_SOURCE_A}" \
  --manifest "${MODEL_MANIFEST_A}" --metadata "${MODEL_METADATA_A}" \
  --expected-shards "${EXPECTED_SAFETENSOR_SHARDS}"
printf 'Model staged privately at %s\nManifest: %s\n' "${MODEL_SOURCE_A}" "${MODEL_MANIFEST_A}"
