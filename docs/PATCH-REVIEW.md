# Patch Review

Patch:

```text
patches/secure-tcp-keyexchange.patch
```

Patch SHA-256:

```text
78ee0621db922b1bf2994b3340e834844fbee41935f0def0f6a6a18c3ec9ad34
```

## Scope

The runtime patch changes one upstream RustDesk Server file:

```text
src/rendezvous_server.rs
```

It does not modify `hbbr`.

The separate patch `patches/libsodium-sys-0.2.7-cross-target.patch` modifies a
local Cargo registry copy of `libsodium-sys 0.2.7/build.rs` only during
Windows-to-ARMv7 cross-builds. It is not a RustDesk Server runtime change.

## Changed Code Areas

The runtime patch:

- changes imports to include `BufMut`, `box_`, and `secretbox`;
- refactors the old `Sink` enum into `SinkType` plus a `Sink` struct;
- adds per-connection encryption state with `Encrypt`;
- adds `Encrypt::dec`, `Encrypt::enc`, and `Encrypt::get_nonce`;
- adds `RendezvousMessage::KeyExchange` handling in `handle_tcp`;
- encrypts outgoing frames in `send_to_sink` after negotiation;
- initializes WebSocket sinks without secure-TCP negotiation;
- initializes TCP sinks with pending encryption state;
- sends server-first `KeyExchange` on TCP when a server key is configured;
- decrypts inbound TCP frames after a symmetric key is installed;
- adds `key_exchange_phase1`;
- adds `key_exchange_phase2`;
- adds `get_symmetric_key_from_msg`;
- adds unit tests for round-trip, malformed input rejection, and
  per-connection key isolation.

Patch size:

```text
src/rendezvous_server.rs | 234 +++++++++++++++++++++++++++++++++++++++++++++--
224 insertions, 10 deletions
```

## Protocol Behavior

Server-first secure TCP handshake:

1. A TCP client connects to `hbbs`.
2. If the server key is configured, `hbbs` generates a fresh Curve25519 box
   keypair for this connection.
3. `hbbs` signs the 32-byte Curve25519 public key with the existing Ed25519
   server secret key.
4. `hbbs` sends a plaintext `RendezvousMessage { key_exchange }` containing
   the signed server Curve25519 public key.
5. The RustDesk client verifies the signature with the configured server public
   key.
6. The client replies with a `KeyExchange` containing its 32-byte Curve25519
   public key and a 48-byte sealed symmetric key.
7. `hbbs` opens the sealed key with the pending per-connection secret.
8. Later rendezvous frames on that TCP connection are encrypted with
   `secretbox`.

The nonce shape matches the client-side secure TCP convention: a 24-byte
secretbox nonce with the little-endian sequence number in the first 8 bytes.
Encode and decode counters are separate and start at zero.

## Compatibility Behavior

- TCP receives the secure TCP handshake only when the configured server key is
  non-empty.
- The NAT helper path uses an empty key and does not receive the handshake.
- WebSocket connections do not receive the secure TCP handshake.
- `KeyExchange` received over WebSocket is logged and ignored.
- Plain clients that ignore the initial `KeyExchange` frame can continue to use
  the existing flow.

## Security Notes

- The Curve25519 secret key is generated per connection.
- The pending exchange secret is consumed with `take()` during phase 2.
- The negotiated symmetric key is scoped to the connection and is not persisted.
- Runtime malformed-input paths return failure without `unwrap()`.
- Failed decryption closes the connection.
- The patch does not log private keys, symmetric keys, API tokens, or client
  ephemeral keys.

## Remaining Risks

- This patch is not an official RustDesk Server release.
- PR #691 was still open and unmerged at the last upstream check.
- Operators should regression-test the exact RustDesk client versions they
  support.
- Any distributed binary must be accompanied by corresponding source and AGPL
  notices.
