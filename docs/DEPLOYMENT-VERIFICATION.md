# Deployment Verification

The earlier local build manifest recorded `deployed=false` because it was
created before the target-system deployment test. That field was later
superseded by direct live-process checksum verification on the ARMv7 target.

## Verified Binary

Release asset:

```text
hbbs-1.1.16-secure-tcp-armv7-linux
```

SHA-256:

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

## Verification Method

The running systemd service was checked without modifying the target system:

1. Read the `rustdesk-hbbs.service` MainPID from systemd.
2. Resolve `/proc/<PID>/exe`.
3. Calculate SHA-256 for that executable.
4. Compare the SHA-256 with the local release artifact.

The process ID is intentionally not recorded here because it changes after each
service restart.

## Test Result

The verified binary was tested successfully after a full target-system reboot:

- `rustdesk-hbbs.service` started correctly;
- Rust-Book login worked;
- the legacy address book loaded and saved correctly;
- logged-in RustDesk remote connections worked;
- the earlier `Failed to secure tcp: deadline has elapsed` problem did not
  occur with this binary.

This does not make the binary official or security-audited.
