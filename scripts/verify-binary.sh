#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$(cd "$script_dir/.." && pwd)"
binary="${BINARY:-$build_root/dist/hbbs}"
output="${OUTPUT:-$build_root/dist/hbbs.verify.txt}"

mkdir -p "$(dirname "$output")"

{
  echo "hbbs binary verification"
  echo "generated_at=$(date -Iseconds)"
  echo "binary=$binary"
  echo
  echo "## stat"
  stat "$binary"
  echo
  echo "## sha256sum"
  sha256sum "$binary"
  echo
  for cmd in file "readelf -h" "readelf -l" "readelf -d" "readelf -A" "readelf -V" "objdump -f" ldd; do
    echo "## $cmd"
    set +e
    $cmd "$binary"
    status=$?
    set -e
    echo "exit_code=$status"
    echo
  done
  echo "## selected strings"
  strings "$binary" | grep -E 'RustDesk ID/Rendezvous Server|1\.1\.16|KeyExchange phase 1|Ignoring KeyExchange|Decryption error|connection secured|expected 2 keys|malformed key sizes|no exchange in progress|failed to open sealed key' || true
} > "$output"

echo "Wrote $output"
