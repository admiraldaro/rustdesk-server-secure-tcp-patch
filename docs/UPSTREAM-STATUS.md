# Upstream Status

Last checked: 2026-08-14

Official upstream:

```text
https://github.com/rustdesk/rustdesk-server
```

At the last check:

- latest official release was `1.1.16`;
- `1.1.16` points to commit
  `73523b31cfd25d77dee862e6fc9f5e1fb5e485ef`;
- upstream `master` was
  `a7736be5e40f85bfc141120dce587e836e5d4b80`;
- PR #691 was open and unmerged;
- PR #689 was open and unmerged;
- current upstream `src/rendezvous_server.rs` did not contain the secure TCP
  `KeyExchange` implementation used by this project.

Relevant upstream pull requests:

- `https://github.com/rustdesk/rustdesk-server/pull/691`
- `https://github.com/rustdesk/rustdesk-server/pull/689`

## When This Patch May No Longer Be Needed

This patch should be re-evaluated when RustDesk Server publishes a release newer
than `1.1.16` or merges equivalent secure TCP rendezvous support.

Before using this patch against a newer upstream:

1. Check the latest official RustDesk Server release.
2. Inspect upstream `src/rendezvous_server.rs`.
3. Search for `KeyExchange`, `secretbox`, `key_exchange_phase1`, and
   `key_exchange_phase2`.
4. Test an unmodified RustDesk client while logged in with a server key
   configured.

If upstream contains equivalent behavior, prefer the official upstream release.
