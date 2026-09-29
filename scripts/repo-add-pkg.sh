#!/usr/bin/env bash
# Push a built package into the dsh-arch-desktop repository.
#
# Pacman reads a repository database, not a directory listing, so a new package
# is only installable after `repo-add` rewrites that database. This script owns
# the whole handoff: it copies the artifact in, refreshes the database, and
# regenerates the client-facing pacman.conf snippet.
#
# Usage:
#   ./scripts/repo-add-pkg.sh <package.pkg.tar.zst> [more packages...]
#
# Package bodies live under packages/. They are published as GitHub Release
# assets, because a Release asset may exceed the 100 MB per-file limit that
# applies to files committed to a normal git repository.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="dsh-arch-desktop"
ARCH_DIR="${REPO_ROOT}/x86_64"
PKG_DIR="${REPO_ROOT}/packages"

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <package.pkg.tar.zst> [more packages...]" >&2
  exit 2
fi

mkdir -p "${ARCH_DIR}" "${PKG_DIR}"

for artifact in "$@"; do
  if [[ ! -f "${artifact}" ]]; then
    echo "error: no such file: ${artifact}" >&2
    exit 1
  fi
  case "${artifact}" in
    *.pkg.tar.zst) ;;
    *)
      echo "error: not an Arch package: ${artifact}" >&2
      exit 1
      ;;
  esac

  name="$(basename "${artifact}")"
  echo "==> adding ${name}"

  # Copy into the published tree first. Keeping one canonical copy avoids the
  # database pointing at a path the release upload never sees.
  cp -f "${artifact}" "${PKG_DIR}/${name}"

  repo-add \
    --include-sigs \
    --nocolor \
    "${ARCH_DIR}/${DB_NAME}.db.tar.zst" \
    "${PKG_DIR}/${name}"

  echo "    recorded in ${DB_NAME}.db.tar.zst"
done

# repo-add writes .db.tar.zst plus symlinks. GitHub Pages serves files, not
# symlinks, so materialize the convenience names as real copies too.
cd "${ARCH_DIR}"
for base in "${DB_NAME}.db" "${DB_NAME}.files"; do
  for ext in "" ".tar.zst" ".tar.gz" ".tar.xz" ".tar.bz2"; do
    target="${base}${ext}"
    if [[ -L "${target}" ]]; then
      link_to="$(readlink "${target}")"
      rm -f "${target}"
      cp -f "${link_to}" "${target}"
      echo "    materialized ${target} -> ${link_to}"
    fi
  done
done

echo
echo "==> repository contents"
ls -la "${ARCH_DIR}"
echo
echo "==> package bodies (publish these as Release assets)"
ls -la "${PKG_DIR}"
