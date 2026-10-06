#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${ROOT}"

readonly OFFLINE_IMAGE="dist/cachefs-3.7-amd64.tar.gz"
readonly OFFLINE_IMAGE_SHA256="3f6fef905bfde8d101162bc620cadcc7deb18044f6d8a4ec182a85dacbaa40c2"

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=1; }
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    fail "missing SHA-256 utility"
  fi
}

required=(
  README.md
  LICENSE
  NOTICE
  docs/DATA-DISCLOSURE.md
  docs/REPRODUCTION-MATRIX.md
  docs/REPRODUCIBILITY.md
  docs/image-provenance.md
  scripts/preflight.sh
  "${OFFLINE_IMAGE}"
)
for path in "${required[@]}"; do
  [[ -f "${path}" ]] || fail "missing required release file: ${path}"
done

if [[ -f "${OFFLINE_IMAGE}" ]]; then
  actual_sha256="$(sha256_file "${OFFLINE_IMAGE}")"
  [[ "${actual_sha256}" == "${OFFLINE_IMAGE_SHA256}" ]] || fail "unexpected offline image SHA-256: ${actual_sha256}"
fi

while IFS= read -r -d '' path; do
  relative="${path#./}"
  case "${relative}" in
    .git/*|runs/*|config/hosts.env|config/model.env|RELEASE-MANIFEST.sha256|.DS_Store|*/.DS_Store|*/__pycache__/*|*.pyc) continue ;;
    "${OFFLINE_IMAGE}") continue ;;
  esac
  case "${relative}" in
    *.safetensors|*.bin|*.pt|*.pth|*.ckpt|*.gguf|*.onnx|*.tar|*.tar.gz|*.img|*.qcow2|*.key|*.pem)
      fail "forbidden release asset: ${relative}" ;;
  esac
  size=$(wc -c < "${path}")
  (( size <= 5242880 )) || fail "unexpected file larger than 5 MiB: ${relative}"
done < <(find . -type f -print0)

patterns=(
  '(^|[^0-9])11\.158\.'
  '(^|[^0-9])172\.(1[6-9]|2[0-9]|3[0-1])\.'
  '(^|[^0-9])192\.168\.'
  '/root/wenqing'
  'gitlab\.alibaba-inc\.com'
  'coro_rpc_lib'
  'OSSAccessKeyId='
  '-----BEGIN.*PRIVATE KEY-----'
  'LTAI[0-9A-Za-z]+'
  '^MODELSCOPE_TOKEN=.+$'
)
for pattern in "${patterns[@]}"; do
  if grep -RInE --exclude-dir=.git --exclude-dir=runs --exclude=audit-public-release.sh --exclude=hosts.env --exclude=model.env --binary-files=without-match -e "${pattern}" .; then
    fail "forbidden disclosure pattern: ${pattern}"
  fi
done

if (( failures )); then
  exit 1
fi

python3 - "${ROOT}" > RELEASE-MANIFEST.sha256 <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
excluded = {".git", "runs", "__pycache__"}
ignored = {"config/hosts.env", "config/model.env", "RELEASE-MANIFEST.sha256"}
for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
    relative_path = path.relative_to(root)
    relative = relative_path.as_posix()
    if relative in ignored or path.name == ".DS_Store" or path.suffix == ".pyc" or any(part in excluded for part in relative_path.parts):
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{digest}  {relative}")
PY
printf 'PASS public release audit\n'
printf 'Manifest: %s/RELEASE-MANIFEST.sha256\n' "${ROOT}"
