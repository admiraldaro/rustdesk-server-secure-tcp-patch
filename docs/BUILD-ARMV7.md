# Build ARMv7 hbbs

This document describes a reproducible source build for `hbbs` only.

Target profile:

```text
Debian 10 Buster
ARMv7 / armhf / 32-bit
EABI5
hard-float
static binary preferred
```

No `hbbr` binary is built or changed.

## Required Tools

Linux, WSL, or another Bash environment:

- `git`
- `bash`
- `python3`
- `rustup`
- `cargo`
- Zig `0.13.0` available as `zig`
- `make`
- `file`
- `readelf`
- `objdump`
- `strings`
- `sha256sum`

Windows PowerShell:

- Git for Windows
- PowerShell 5+
- MSYS2 with UCRT64 tools for `bash`, `make`, `file`, `readelf`, `objdump`,
  and `strings`
- network access to download rustup and Zig, unless already cached by the
  script

The PowerShell build script downloads and verifies:

- rustup-init for Windows x86_64
- Zig `0.13.0` for Windows x86_64

## Bash Build

From the repository root:

```sh
bash scripts/fetch-source.sh
bash scripts/apply-patch.sh
bash scripts/build-armv7.sh
bash scripts/verify-binary.sh
```

The Bash script defaults to a local Cargo home:

```text
work/cargo
```

This prevents the dependency build-support patch from being applied to a
user's normal global Cargo registry by default.

Environment overrides:

```sh
REPOSITORY_URL=https://github.com/rustdesk/rustdesk-server.git
BASE_COMMIT=73523b31cfd25d77dee862e6fc9f5e1fb5e485ef
SOURCE_DIR="$PWD/work/source"
DIST_DIR="$PWD/dist"
TARGET=armv7-unknown-linux-musleabihf
RUST_TOOLCHAIN=1.85.1
ZIG=zig
```

## Windows PowerShell Build

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\fetch-source.ps1
powershell -ExecutionPolicy Bypass -File scripts\apply-patch.ps1
powershell -ExecutionPolicy Bypass -File scripts\build-armv7.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-binary.ps1
```

The PowerShell build keeps Rust and Cargo under:

```text
work/tools/rust
```

It uses temporary no-space paths for wrappers where needed, because some
cross-build tools do not handle spaces in linker/helper paths reliably.

## What The Scripts Verify

`fetch-source` verifies:

- base commit is exactly `73523b31cfd25d77dee862e6fc9f5e1fb5e485ef`;
- `libs/hbb_common` submodule is exactly
  `83419b6549636ee39dacef7776c473f5802e08d6`;
- `Cargo.lock` SHA-256 is
  `f5e17e33f48875a3a63c14002a6d94278ac6a02381c2e4c1934900823bc31528`.

`apply-patch` verifies:

- the source is still at the expected base commit;
- `patches/secure-tcp-keyexchange.patch` applies cleanly;
- the patch changes only `src/rendezvous_server.rs`;
- `git diff --check` passes.

`build-armv7` verifies:

- `libsodium-sys 0.2.7` is pinned with the expected crates.io checksum;
- `libsodium-sys 0.2.7/build.rs` has the expected original hash;
- the build-support patch applies cleanly;
- the patched dependency build script has the expected patched hash;
- the produced `hbbs` is an ELF32 ARM EABI5 hard-float static executable;
- no `hbbr` output is produced.

`verify-binary` writes:

```text
dist/hbbs.verify.txt
```

## Outputs

Generated output is ignored by Git:

```text
dist/hbbs
dist/hbbs.sha256
dist/hbbs.build-info.txt
dist/hbbs.test-log.txt
dist/hbbs.verify.txt
work/
```

Do not commit generated binaries to this repository.

## Non-Bit-For-Bit Caveat

This build profile is reproducible in source, inputs, target, and verification
checks, but it is not guaranteed to be bit-for-bit reproducible across host
paths and tool installations. Rust panic strings and linker metadata can include
host-path-sensitive data.

Use the manifest, patch hashes, tool versions, source commit, and binary
verification report to identify a build.
