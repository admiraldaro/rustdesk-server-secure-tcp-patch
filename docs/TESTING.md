# Testing

This project has two levels of testing:

- source and unit testing on the build host;
- real integration testing with an unmodified RustDesk client and your actual
  `hbbs`/`hbbr` deployment.

## Source Checks

```sh
bash scripts/fetch-source.sh
bash scripts/apply-patch.sh
```

Expected result:

- the pinned upstream source is fetched;
- the patch applies cleanly;
- only `src/rendezvous_server.rs` is changed.

## Unit Tests

The build helper runs the secure TCP unit tests added by the patch:

```sh
cargo test --locked --lib key_exchange -- --nocapture
```

Expected secure TCP tests:

```text
key_exchange_round_trip
key_exchange_rejects_garbage
key_exchange_secret_does_not_open_another_connections_payload
```

## Binary Verification

After building:

```sh
bash scripts/verify-binary.sh
```

Expected binary properties:

```text
ELF 32-bit
ARM
EABI5
hard-float ABI
statically linked
no dynamic section
```

The `0.1.0` ARMv7 release binary has SHA-256:

```text
2a9b2b2386f97bc9cdd4781df87348517ec8c709acc7d24045e5dc31bb6e0268
```

It was verified against the executable currently run by the `rustdesk-hbbs`
systemd service on the ARMv7 target by resolving `/proc/<PID>/exe` from the
service MainPID and comparing SHA-256. The PID is not recorded because it
changes after restart.

## Manual Integration Test

Before using a patched `hbbs` in production, test with the real client and
server topology you intend to support.

Minimum checklist:

- existing RustDesk ID Server and Relay Server settings are unchanged;
- server public key remains configured in the client;
- API login succeeds;
- the user appears logged in;
- address book sync still works if you use a custom API;
- remote connection works while logged out;
- remote connection works while logged in;
- `hbbs` logs show no secure TCP decryption or key-exchange errors;
- `hbbr` remains stock unless you have a separate reason to change it.

The historical failure this patch addresses is:

```text
Failed to secure tcp: deadline has elapsed
```

If that error remains after replacing `hbbs`, check that the running service is
the patched binary, the server key is unchanged, and the client is connecting to
the intended rendezvous server.

The `0.1.0` binary was successfully tested after a target-system reboot with:

- `rustdesk-hbbs` starting correctly;
- Rust-Book login;
- legacy address-book load and save;
- logged-in RustDesk remote connections;
- no recurrence of `Failed to secure tcp: deadline has elapsed`.
