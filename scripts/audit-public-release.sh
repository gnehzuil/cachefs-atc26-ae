#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${ROOT}"

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=1; }

required=(README.md LICENSE NOTICE docs/DATA-DISCLOSURE.md docs/REPRODUCTION-MATRIX.md docs/REPRODUCIBILITY.md docs/BINARY-NOTICE-AUDIT.md docs/HOTCRP-SUBMISSION-CHECKLIST.md scripts/preflight.sh)
for path in "${required[@]}"; do
  [[ -f "${path}" ]] || fail "missing required release file: ${path}"
done

while IFS= read -r -d '' path; do
  relative="${path#./}"
  case "${relative}" in
    .git/*|runs/*|config/hosts.env|config/model.env) continue ;;
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
  if grep -RInE --exclude-dir=.git --exclude=audit-public-release.sh --exclude=hosts.env --exclude=model.env --binary-files=without-match -e "${pattern}" .; then
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
excluded = {".git", "runs"}
ignored = {"config/hosts.env", "config/model.env", "RELEASE-MANIFEST.sha256"}
for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
    relative = path.relative_to(root).as_posix()
    if relative in ignored or any(part in excluded for part in path.relative_to(root).parts):
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{digest}  {relative}")
PY
printf 'PASS public release audit\n'
printf 'Manifest: %s/RELEASE-MANIFEST.sha256\n' "${ROOT}"
