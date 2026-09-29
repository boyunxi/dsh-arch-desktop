#!/usr/bin/env bash
# Verify that the repository database is internally consistent and that every
# package body it references is actually present. Run before publishing: a
# database that names a missing file makes `pacman -Syu` fail on every client.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="dsh-arch-desktop"
DB="${REPO_ROOT}/x86_64/${DB_NAME}.db.tar.zst"
PKG_DIR="${REPO_ROOT}/packages"

if [[ ! -f "${DB}" ]]; then
  echo "error: database not found: ${DB}" >&2
  exit 1
fi

echo "==> database: ${DB}"
echo "==> entries:"
tar -tf "${DB}" | grep '/$' | sed 's|/$||' | sed 's/^/    /'

fail=0
while read -r entry; do
  [[ -z "${entry}" ]] && continue
  pkgdir="$(mktemp -d)"
  tar -xf "${DB}" -C "${pkgdir}" "${entry}/desc"
  filename="$(awk '/^%FILENAME%$/{getline; print; exit}' "${pkgdir}/${entry}/desc")"
  sha="$(awk '/^%SHA256SUM%$/{getline; print; exit}' "${pkgdir}/${entry}/desc")"
  rm -rf "${pkgdir}"

  body="${PKG_DIR}/${filename}"
  if [[ ! -f "${body}" ]]; then
    echo "    MISSING BODY: ${filename}" >&2
    fail=1
    continue
  fi

  actual="$(sha256sum "${body}" | cut -d' ' -f1)"
  if [[ "${actual}" != "${sha}" ]]; then
    echo "    CHECKSUM MISMATCH: ${filename}" >&2
    echo "      database: ${sha}" >&2
    echo "      actual:   ${actual}" >&2
    fail=1
    continue
  fi

  echo "    ok  ${filename} (${actual:0:16}...)"
done < <(tar -tf "${DB}" | grep '/$' | sed 's|/$||')

if (( fail )); then
  echo >&2
  echo "==> repository is NOT publishable" >&2
  exit 1
fi

echo
echo "==> all package bodies present and checksums match"
