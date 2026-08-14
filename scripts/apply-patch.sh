#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$(cd "$script_dir/.." && pwd)"
source_dir="${SOURCE_DIR:-$build_root/work/source}"
patch_file="${PATCH_FILE:-$build_root/patches/secure-tcp-keyexchange.patch}"
expected_base="73523b31cfd25d77dee862e6fc9f5e1fb5e485ef"

head_commit="$(git -C "$source_dir" rev-parse HEAD)"
test "$head_commit" = "$expected_base"

git -C "$source_dir" apply --check "$patch_file"
git -C "$source_dir" apply "$patch_file"
git -C "$source_dir" diff --check

changed="$(git -C "$source_dir" diff --name-only)"
test "$changed" = "src/rendezvous_server.rs"

echo "Applied secure TCP KeyExchange patch."
