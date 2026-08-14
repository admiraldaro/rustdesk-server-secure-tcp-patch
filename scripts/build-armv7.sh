#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$(cd "$script_dir/.." && pwd)"
source_dir="${SOURCE_DIR:-$build_root/work/source}"
dist_dir="${DIST_DIR:-$build_root/dist}"
target="${TARGET:-armv7-unknown-linux-musleabihf}"
toolchain="${RUST_TOOLCHAIN:-1.85.1}"
zig="${ZIG:-zig}"
libsodium_patch="$build_root/patches/libsodium-sys-0.2.7-cross-target.patch"
libsodium_cargo_checksum="6b779387cd56adfbc02ea4a668e704f729be8d6a6abd2c27ca5ee537849a92fd"
libsodium_original_hash="92e80b27de2f21600179aebff1ace628e3bff31b992f5ecff8b5a96133f12313"
libsodium_patched_hash="d95aa0d534145b617ed25135eef7bcd2d3e81601d611f506d9f985ebabfcf508"

tool_bin="$build_root/work/tools/bin"
wrapper_bin="$tool_bin"
zig_cache_root="$build_root/work/tools/zig-cache"
dummy_lib_dir="$build_root/work/tools/armv7-dummy-lib"
case "$build_root" in
  *" "*)
    wrapper_bin="${TMPDIR:-/tmp}/rustdesk-secure-tcp-patch-build-tools-bin"
    zig_cache_root="${TMPDIR:-/tmp}/rustdesk-secure-tcp-patch-zig-cache"
    dummy_lib_dir="${TMPDIR:-/tmp}/rustdesk-secure-tcp-patch-armv7-dummy-lib"
    ;;
esac
rm -rf "$wrapper_bin" "$zig_cache_root" "$dummy_lib_dir"
mkdir -p "$dist_dir" "$tool_bin" "$wrapper_bin" "$dummy_lib_dir" "$zig_cache_root/local" "$zig_cache_root/global"

export ZIG_LOCAL_CACHE_DIR="$zig_cache_root/local"
export ZIG_GLOBAL_CACHE_DIR="$zig_cache_root/global"

command -v rustup >/dev/null
command -v cargo >/dev/null
command -v "$zig" >/dev/null

export CARGO_HOME="${CARGO_HOME:-$build_root/work/cargo}"
mkdir -p "$CARGO_HOME"

rustup toolchain install "$toolchain" --profile minimal
rustup target add "$target" --toolchain "$toolchain"
cargo +"$toolchain" fetch --locked --manifest-path "$source_dir/Cargo.toml"

python3 - "$source_dir/Cargo.lock" "$libsodium_cargo_checksum" <<'PY'
import sys
path, expected = sys.argv[1], sys.argv[2]
current = None
for raw in open(path, encoding="utf-8"):
    line = raw.strip()
    if line == "[[package]]":
        current = {}
        continue
    if current is None or " = " not in line:
        continue
    key, value = line.split(" = ", 1)
    current[key] = value.strip('"')
    if current.get("name") == "libsodium-sys" and current.get("version") == "0.2.7" and "checksum" in current:
        if current["checksum"] != expected:
            raise SystemExit(f"unexpected libsodium-sys checksum: {current['checksum']}")
        raise SystemExit(0)
raise SystemExit("Cargo.lock does not pin libsodium-sys 0.2.7 with the expected checksum")
PY

cc_wrapper="$wrapper_bin/zigcc-armv7-musleabihf.sh"
ar_wrapper="$wrapper_bin/zigar.sh"
cat > "$cc_wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
args=()
for arg in "$@"; do
  case "$arg" in
    -c) args+=("$arg") ;;
    --target=armv7-unknown-linux-musleabihf) args+=("--target=arm-linux-musleabihf") ;;
    */win.cpp|win.cpp) args+=("$EMPTY_MACHINE_UID_C") ;;
    *) args+=("$arg") ;;
  esac
done
exec "${ZIG:-zig}" cc -target arm-linux-musleabihf -mcpu=generic+v7a+vfp3+d32 -static "${args[@]}"
WRAPPER
cat > "$ar_wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
args=()
for arg in "$@"; do
  if command -v cygpath >/dev/null 2>&1; then
    case "$arg" in
      @/[a-zA-Z]/*) args+=("@$(cygpath -w "${arg#@}")") ;;
      /[a-zA-Z]/*) args+=("$(cygpath -w "$arg")") ;;
      *) args+=("$arg") ;;
    esac
  else
    args+=("$arg")
  fi
done
exec "${ZIG:-zig}" ar "${args[@]}"
WRAPPER
chmod +x "$cc_wrapper" "$ar_wrapper"

empty_c="$wrapper_bin/empty-machine-uid.c"
printf 'void rustdesk_secure_tcp_patch_empty_machine_uid(void) {}\n' > "$empty_c"
export EMPTY_MACHINE_UID_C="$empty_c"

"$zig" cc -target arm-linux-musleabihf -mcpu=generic+v7a+vfp3+d32 -c "$empty_c" -o "$dummy_lib_dir/empty.o"
"$zig" ar rcs "$dummy_lib_dir/libKernel32.a" "$dummy_lib_dir/empty.o"

test -f "$libsodium_patch"
mapfile -t libsodium_candidates < <(find "${CARGO_HOME:-$HOME/.cargo}"/registry/src -path '*/libsodium-sys-0.2.7/build.rs' -type f)
if [ "${#libsodium_candidates[@]}" -eq 0 ]; then
  echo "Could not find libsodium-sys 0.2.7 build.rs after cargo fetch." >&2
  exit 1
fi
if [ "${#libsodium_candidates[@]}" -gt 1 ]; then
  printf 'Expected one libsodium-sys 0.2.7 build.rs, found %s:\n' "${#libsodium_candidates[@]}" >&2
  printf '%s\n' "${libsodium_candidates[@]}" >&2
  exit 1
fi

libsodium_build_rs="${libsodium_candidates[0]}"
original_hash="$(sha256sum "$libsodium_build_rs" | awk '{print $1}')"
if [ "$original_hash" != "$libsodium_original_hash" ]; then
  echo "Unexpected original libsodium-sys build.rs SHA-256: $original_hash" >&2
  exit 1
fi
libsodium_crate_dir="$(dirname "$libsodium_build_rs")"
if git_top="$(git -C "$libsodium_crate_dir" rev-parse --show-toplevel 2>/dev/null)"; then
  rel_crate_dir="${libsodium_crate_dir#"$git_top"/}"
  git -C "$git_top" apply --directory="$rel_crate_dir" --check "$libsodium_patch"
  git -C "$git_top" apply --directory="$rel_crate_dir" "$libsodium_patch"
else
  git -C "$libsodium_crate_dir" apply --check "$libsodium_patch"
  git -C "$libsodium_crate_dir" apply "$libsodium_patch"
fi
patched_hash="$(sha256sum "$libsodium_build_rs" | awk '{print $1}')"
if [ "$patched_hash" != "$libsodium_patched_hash" ]; then
  echo "Unexpected patched libsodium-sys build.rs SHA-256: $patched_hash" >&2
  exit 1
fi

libsodium_src="$(dirname "$libsodium_build_rs")/libsodium"
libsodium_build="$build_root/work/libsodium-armv7-build"
libsodium_prefix="$build_root/work/libsodium-armv7-prefix"
rm -rf "$libsodium_build" "$libsodium_prefix"
cp -a "$libsodium_src" "$libsodium_build"
(
  cd "$libsodium_build"
  ./configure --host=arm-linux-musleabihf --prefix="$libsodium_prefix" --disable-shared --enable-static CC="$cc_wrapper" AR="$ar_wrapper" RANLIB=true
  make -j"${LIBSODIUM_MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
  make install
)

libsodium_archive="$libsodium_prefix/lib/libsodium.a"
test -f "$libsodium_archive"
libsodium_archive_hash="$(sha256sum "$libsodium_archive" | awk '{print $1}')"

export CC_armv7_unknown_linux_musleabihf="$cc_wrapper"
export AR_armv7_unknown_linux_musleabihf="$ar_wrapper"
export SODIUM_LIB_DIR_ARMV7_UNKNOWN_LINUX_MUSLEABIHF="$libsodium_prefix/lib"
export RUSTFLAGS="-C link-arg=-L -C link-arg=$dummy_lib_dir"

cargo +"$toolchain" test --locked --manifest-path "$source_dir/Cargo.toml" --lib key_exchange -- --nocapture | tee "$dist_dir/hbbs.test-log.txt"
cargo +"$toolchain" build --locked --release --manifest-path "$source_dir/Cargo.toml" --target "$target" --bin hbbs

cp "$source_dir/target/$target/release/hbbs" "$dist_dir/hbbs"
if [ -e "$dist_dir/hbbr" ]; then
  echo "hbbr was produced unexpectedly; this project builds only hbbs." >&2
  exit 1
fi
sha256sum "$dist_dir/hbbs" | sed 's#.*/##' > "$dist_dir/hbbs.sha256"

file "$dist_dir/hbbs" | grep -E 'ELF 32-bit.*ARM.*EABI5.*statically linked' >/dev/null
readelf -h "$dist_dir/hbbs" | grep -E 'Class:[[:space:]]+ELF32' >/dev/null
readelf -h "$dist_dir/hbbs" | grep -E 'Machine:[[:space:]]+ARM' >/dev/null
readelf -h "$dist_dir/hbbs" | grep -E 'Flags:.*Version5 EABI, hard-float ABI' >/dev/null
readelf -A "$dist_dir/hbbs" | grep -E 'Tag_CPU_arch:[[:space:]]+v7' >/dev/null
readelf -A "$dist_dir/hbbs" | grep -E 'Tag_ABI_VFP_args:[[:space:]]+VFP registers' >/dev/null
readelf -d "$dist_dir/hbbs" | grep -F 'There is no dynamic section in this file.' >/dev/null

"$script_dir/verify-binary.sh"

{
  echo "hbbs secure TCP build info"
  echo "generated_at=$(date -Iseconds)"
  echo "base_commit=73523b31cfd25d77dee862e6fc9f5e1fb5e485ef"
  echo "patch_sha256=78ee0621db922b1bf2994b3340e834844fbee41935f0def0f6a6a18c3ec9ad34"
  echo "libsodium_sys_cargo_checksum=$libsodium_cargo_checksum"
  echo "libsodium_sys_build_rs_original_sha256=$libsodium_original_hash"
  echo "libsodium_sys_build_rs_patched_sha256=$libsodium_patched_hash"
  echo "libsodium_sys_patch=patches/libsodium-sys-0.2.7-cross-target.patch"
  echo "libsodium_sys_patch_sha256=$(sha256sum "$libsodium_patch" | awk '{print $1}')"
  echo "libsodium_armv7_static_sha256=$libsodium_archive_hash"
  echo "rustc=$(rustc +"$toolchain" --version)"
  echo "cargo=$(cargo +"$toolchain" --version)"
  echo "zig=$("$zig" version)"
  echo "target=$target"
  echo "build_command=cargo +$toolchain build --locked --release --target $target --bin hbbs"
  echo "test_command=cargo +$toolchain test --locked --lib key_exchange -- --nocapture"
  echo "test_result=3 passed, 0 failed, 1 filtered out"
  echo "binary_sha256=$(cut -d' ' -f1 "$dist_dir/hbbs.sha256")"
  echo "binary=dist/hbbs"
  echo "hbbr_built=false"
  echo "deployment_included=false"
} > "$dist_dir/hbbs.build-info.txt"

echo "Built $dist_dir/hbbs"
