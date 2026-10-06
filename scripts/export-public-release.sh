#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-${ROOT}/../cachefs-atc26-ae-public-export}"
VERSION="${VERSION:-1.0.0}"
NAME="cachefs-atc26-ae"
FINAL="${OUTPUT}/${NAME}"
ARCHIVE="${OUTPUT}/${NAME}-${VERSION}.tar.gz"
CHECKSUM="${ARCHIVE}.sha256"

for path in "${FINAL}" "${ARCHIVE}" "${CHECKSUM}"; do
  [[ ! -e "${path}" ]] || {
    echo "Refusing to overwrite existing export: ${path}" >&2
    exit 1
  }
done

mkdir -p "${OUTPUT}"
TEMP="$(mktemp -d "${OUTPUT}/.export.XXXXXX")"
trap 'rm -rf "${TEMP}"' EXIT
STAGE="${TEMP}/${NAME}"
mkdir -p "${STAGE}/config" "${STAGE}/dist" "${STAGE}/docs/assets" "${STAGE}/scripts"

for path in .gitignore LICENSE NOTICE README.md; do
  cp -p "${ROOT}/${path}" "${STAGE}/${path}"
done
cp -p "${ROOT}/config/hosts.example.env" "${ROOT}/config/model.example.env" "${STAGE}/config/"
cp -p "${ROOT}/dist/cachefs-3.7-amd64.tar.gz" "${STAGE}/dist/"
cp -p "${ROOT}/docs/"*.md "${STAGE}/docs/"
cp -p "${ROOT}/docs/assets/"* "${STAGE}/docs/assets/"
cp -p "${ROOT}/scripts/"*.sh "${ROOT}/scripts/"*.py "${STAGE}/scripts/"
chmod +x "${STAGE}/scripts/"*.sh "${STAGE}/scripts/"*.py

(
  cd "${STAGE}"
  rm -rf runs config/hosts.env config/model.env RELEASE-MANIFEST.sha256 scripts/__pycache__
  bash scripts/audit-public-release.sh .
)

mv "${STAGE}" "${FINAL}"
if command -v xattr >/dev/null 2>&1; then
  xattr -cr "${FINAL}"
fi
COPYFILE_DISABLE=1 tar -C "${OUTPUT}" -czf "${ARCHIVE}" "${NAME}"
if command -v sha256sum >/dev/null 2>&1; then
  archive_sha256="$(sha256sum "${ARCHIVE}" | cut -d ' ' -f 1)"
else
  archive_sha256="$(shasum -a 256 "${ARCHIVE}" | cut -d ' ' -f 1)"
fi
printf '%s  %s\n' "${archive_sha256}" "$(basename "${ARCHIVE}")" > "${CHECKSUM}"
printf 'Created audited public release directory: %s\n' "${FINAL}"
printf 'Created Zenodo archive: %s\n' "${ARCHIVE}"
printf 'Archive checksum: %s\n' "${CHECKSUM}"
