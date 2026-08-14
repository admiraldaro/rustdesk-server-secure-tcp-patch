# Source Manifest

Prepared for: RustDesk Server Secure TCP Patch

Last upstream check: 2026-08-14

Binary deployment verification: 2026-08-14

## Upstream Source

- Repository: `https://github.com/rustdesk/rustdesk-server.git`
- Base release: `1.1.16`
- Base commit: `73523b31cfd25d77dee862e6fc9f5e1fb5e485ef`
- Base commit date: `2026-07-21T05:26:35+08:00`
- Base commit subject: `bump version`
- Submodule `libs/hbb_common`: `83419b6549636ee39dacef7776c473f5802e08d6`

The helper scripts clone this upstream repository, check out the exact base
commit, initialize submodules, and verify `Cargo.lock`.

## Upstream Status At Last Check

- Latest official RustDesk Server release: `1.1.16`
- Latest release published: `2026-07-20T22:25:36Z`
- Upstream `master` ref checked: `a7736be5e40f85bfc141120dce587e836e5d4b80`
- Secure TCP rendezvous `KeyExchange` support was not present in official
  `master` at the time of this check.

Relevant upstream links:

- `https://github.com/rustdesk/rustdesk-server`
- `https://github.com/rustdesk/rustdesk-server/releases/tag/1.1.16`
- `https://github.com/rustdesk/rustdesk-server/pull/689`
- `https://github.com/rustdesk/rustdesk-server/pull/691`

## Runtime Patch

- Patch file: `patches/secure-tcp-keyexchange.patch`
- Patch SHA-256:
  `78ee0621db922b1bf2994b3340e834844fbee41935f0def0f6a6a18c3ec9ad34`
- Upstream inspiration: RustDesk Server PR #691
- PR #691 head: `9ff251da24a164279bf4952b4015498d43027115`
- PR #691 status at last check: open, unmerged
- Changed upstream file: `src/rendezvous_server.rs`

The local runtime patch excludes `Dockerfile.custom` and other non-runtime
material from PR #691. It changes only `src/rendezvous_server.rs`.

## Related PR Not Used

PR #689 was reviewed but not selected.

- PR #689 head: `f1bd02a56fb15345033c863d69c81002fc2bb7ac`
- PR #689 status at last check: open, unmerged

Reason: PR #689 is smaller, but it lacks the later per-connection ephemeral key
handling, WebSocket guard, and secure-TCP unit tests present in PR #691.

## Dependency Build-Support Patch

- Patch file: `patches/libsodium-sys-0.2.7-cross-target.patch`
- Patch SHA-256:
  `1e1596c4d52f770578b8a3c288cbd41db1d02b561c6bd638b7fd4eba50c9b3e6`
- Affected dependency: `libsodium-sys 0.2.7`
- Affected dependency file: `build.rs`
- Original `build.rs` SHA-256:
  `92e80b27de2f21600179aebff1ace628e3bff31b992f5ecff8b5a96133f12313`
- Patched `build.rs` SHA-256:
  `d95aa0d534145b617ed25135eef7bcd2d3e81601d611f506d9f985ebabfcf508`
- Cargo.lock `libsodium-sys 0.2.7` checksum:
  `6b779387cd56adfbc02ea4a668e704f729be8d6a6abd2c27ca5ee537849a92fd`

This is a build-host workaround only. It does not modify RustDesk Server
runtime source.

## Target Build Profile

The documented target is:

```text
Debian 10 Buster
ARMv7 / armhf / 32-bit
EABI5
hard-float
glibc 2.28 compatible host
static hbbs binary preferred
```

No compiled binary is part of this repository.

## Verified Binary Release Asset

The optional `0.1.0` GitHub Release binary asset is:

```text
hbbs-1.1.16-secure-tcp-armv7-linux
```

It is copied unchanged from the local build artifact:

```text
hbbs-patched/dist/hbbs
```

The local build artifact and copied release asset have SHA-256:

```text
2a9b2b2386f97bc9cdd4781df87348517ec8c709acc7d24045e5dc31bb6e0268
```

Size:

```text
7632084 bytes
```

Format:

```text
ELF 32-bit LSB executable, ARM, EABI5, hard-float ABI, statically linked
```

The earlier local build metadata said `deployed=false` because it was written
before target deployment. That status was superseded by direct live-process
checksum verification on the ARMv7 target: systemd MainPID lookup,
`/proc/<PID>/exe` resolution, and SHA-256 comparison proved that the running
`rustdesk-hbbs` executable matched the local artifact above bit-for-bit. The
PID is not recorded because it changes after restart.

The verified target test included successful reboot persistence, Rust-Book
login, legacy address-book load/save, and logged-in RustDesk remote
connections.

No bit-for-bit rebuild claim is made.
