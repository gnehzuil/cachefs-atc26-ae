#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-${ROOT}/../cachefs-atc26-ae-public-export}"
NAME="cachefs-atc26-ae"
FINAL="${OUTPUT}/${NAME}"

[[ ! -e "${FINAL}" ]] || {
  echo "Refusing to overwrite existing export: ${FINAL}" >&2
  exit 1
}

mkdir -p "${OUTPUT}"
TEMP="$(mktemp -d "${OUTPUT}/.export.XXXXXX")"
trap 'rm -rf "${TEMP}"' EXIT
STAGE="${TEMP}/${NAME}"
mkdir -p "${STAGE}/config" "${STAGE}/docs" "${STAGE}/scripts"

for path in .gitignore LICENSE NOTICE README.md; do
  cp -p "${ROOT}/${path}" "${STAGE}/${path}"
done
cp -p "${ROOT}/config/hosts.example.env" "${ROOT}/config/model.example.env" "${STAGE}/config/"
cp -p "${ROOT}/docs/"*.md "${STAGE}/docs/"
cp -p "${ROOT}/scripts/"*.sh "${STAGE}/scripts/"
cp -p "${ROOT}/scripts/"*.py "${STAGE}/scripts/"
chmod +x "${STAGE}/scripts/"*.sh "${STAGE}/scripts/"*.py

(
  cd "${STAGE}"
  rm -rf runs config/hosts.env config/model.env RELEASE-MANIFEST.sha256 scripts/__pycache__
  bash scripts/audit-public-release.sh .
)

mv "${STAGE}" "${FINAL}"
printf 'Created audited public release export: %s\n' "${FINAL}"
