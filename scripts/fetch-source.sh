#!/usr/bin/env bash
set -euo pipefail

repository_url="${REPOSITORY_URL:-https://github.com/rustdesk/rustdesk-server.git}"
base_commit="${BASE_COMMIT:-73523b31cfd25d77dee862e6fc9f5e1fb5e485ef}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$(cd "$script_dir/.." && pwd)"
source_dir="${SOURCE_DIR:-$build_root/work/source}"
expected_common="83419b6549636ee39dacef7776c473f5802e08d6"
expected_lock_blob="f018be6cc3c34fb13955efb4acfb7fba5d59efaa"

source_parent="$(dirname "$source_dir")"
source_name="$(basename "$source_dir")"
mkdir -p "$source_parent"
source_parent="$(cd "$source_parent" && pwd -P)"
source_dir="$source_parent/$source_name"
case "$source_dir/" in
  "$build_root"/work/*) ;;
  *) echo "Refusing to operate outside $build_root/work: $source_dir" >&2; exit 1 ;;
esac

mkdir -p "$build_root/work"
rm -rf "$source_dir"

git clone --recursive "$repository_url" "$source_dir"
git -C "$source_dir" checkout --detach "$base_commit"
git -C "$source_dir" submodule update --init --recursive

actual="$(git -C "$source_dir" rev-parse HEAD)"
test "$actual" = "$base_commit"

submodule="$(git -C "$source_dir" ls-files -s libs/hbb_common | awk '{print $2}')"
test "$submodule" = "$expected_common"

lock_blob="$(git -C "$source_dir" rev-parse HEAD:Cargo.lock)"
test "$lock_blob" = "$expected_lock_blob"

echo "Fetched pinned RustDesk Server source at $base_commit"
