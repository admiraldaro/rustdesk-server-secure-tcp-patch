# RustDesk Server Secure TCP Patch

Unofficial community source patch for the open-source RustDesk Server `hbbs`
rendezvous service.

This repository provides a source-level patch that adds secure TCP
`KeyExchange` handling to `hbbs` for logged-in RustDesk clients that have a
server key configured. It is intended for operators who understand that RustDesk
Server remains a separate upstream AGPL project.

This is not affiliated with RustDesk, not endorsed by RustDesk, and not an
official RustDesk Server release.

## What This Fixes

Some RustDesk clients use a secure TCP rendezvous path when all of these are
true:

- the client is logged in to an API server;
- a RustDesk Server public key is configured;
- the client opens a TCP rendezvous connection to `hbbs`.

With upstream RustDesk Server `1.1.16`, that path can fail with:

```text
Failed to secure tcp: deadline has elapsed
```

The patch implements the server side of the TCP `KeyExchange` flow in
`src/rendezvous_server.rs`.

## What Is Included

- `patches/secure-tcp-keyexchange.patch`: the RustDesk Server runtime patch.
- `patches/libsodium-sys-0.2.7-cross-target.patch`: an optional build-host
  workaround for Windows-to-ARMv7 cross-builds.
- `scripts/`: helper scripts to fetch pinned upstream source, apply the patch,
  build `hbbs`, and verify the output.
- `docs/`: source manifest, patch review, build notes, testing notes, and
  license guidance.

## What Is Not Included

- no `hbbs` binary in normal Git history;
- no `hbbr` binary;
- no official RustDesk Server release;
- no RustDesk keys;
- no deployment logs;
- no private hostnames, IP addresses, service files, or databases.

## Prebuilt ARMv7 Binary

GitHub Releases may include an optional prebuilt ARMv7 Linux `hbbs` binary:

```text
hbbs-1.1.16-secure-tcp-armv7-linux
```

The `0.1.0` binary release asset is the exact community-built artifact deployed
and successfully tested on an ARMv7 Linux target. It is unofficial, has not
received a formal security audit, and is provided without warranty.

Prefer building from source when possible. If you use the prebuilt binary:

- verify the SHA-256 checksum before running it;
- use your own RustDesk server keys and existing server configuration;
- do not expect keys, databases, or service configuration to be embedded;
- keep `hbbr` unchanged unless you have a separate reason to change it;
- confirm your system can run 32-bit ARM Linux hard-float executables;
- do not use it on ARM64-only, x86, x86-64, or incompatible systems.

The binary and matching Corresponding Source are distributed separately as
GitHub Release assets and are licensed under AGPL-3.0.

### Binary Installation Example

This project does not automatically install or overwrite server files.

```sh
sha256sum -c hbbs-1.1.16-secure-tcp-armv7-linux.sha256
chmod 0755 hbbs-1.1.16-secure-tcp-armv7-linux
./hbbs-1.1.16-secure-tcp-armv7-linux --version
```

Generic replacement procedure:

1. Stop the existing `hbbs` service.
2. Back up the old executable.
3. Copy the new binary into place.
4. Preserve the existing database, key files, and service configuration.
5. Start the service.
6. Inspect logs.
7. Test remote connections while logged out.
8. Test remote connections while logged in.
9. Roll back if anything regresses.

## Quick Start

Linux, WSL, or another Bash environment:

```sh
git clone https://github.com/admiraldaro/rustdesk-server-secure-tcp-patch.git
cd rustdesk-server-secure-tcp-patch
bash scripts/fetch-source.sh
bash scripts/apply-patch.sh
bash scripts/build-armv7.sh
bash scripts/verify-binary.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/admiraldaro/rustdesk-server-secure-tcp-patch.git
cd rustdesk-server-secure-tcp-patch
powershell -ExecutionPolicy Bypass -File scripts\fetch-source.ps1
powershell -ExecutionPolicy Bypass -File scripts\apply-patch.ps1
powershell -ExecutionPolicy Bypass -File scripts\build-armv7.ps1
powershell -ExecutionPolicy Bypass -File scripts\verify-binary.ps1
```

The helper build writes generated source and outputs under ignored local
directories:

```text
work/
dist/
```

Only `hbbs` is built. `hbbr` is intentionally not changed.

## Base Source

The patch is prepared for official RustDesk Server `1.1.16` at commit:

```text
73523b31cfd25d77dee862e6fc9f5e1fb5e485ef
```

See [SOURCE_MANIFEST.md](SOURCE_MANIFEST.md) for the exact upstream and patch
provenance.

## Documentation

- [Build ARMv7 hbbs](docs/BUILD-ARMV7.md)
- [Patch Review](docs/PATCH-REVIEW.md)
- [Testing](docs/TESTING.md)
- [Deployment Verification](docs/DEPLOYMENT-VERIFICATION.md)
- [Upstream Status](docs/UPSTREAM-STATUS.md)
- [License Compliance](docs/LICENSE-COMPLIANCE.md)
- [Private Context Policy](docs/PRIVATE-CONTEXT-POLICY.md)
- [Publishing Checklist](PUBLISHING.md)

## Related Project

Rust-Book is the separate MIT-licensed RustDesk-compatible account and legacy
address-book API project:

```text
https://github.com/admiraldaro/rust-book
```

This repository is only for the AGPL-3.0 RustDesk Server `hbbs` source patch
and optional release assets.

## License

This repository is licensed under the GNU Affero General Public License version
3. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

If you distribute a modified `hbbs` binary or operate a modified network server
for users, make sure you satisfy the AGPL source and notice obligations.
