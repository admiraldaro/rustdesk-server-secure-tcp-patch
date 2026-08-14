# Private Context Policy

The original investigation used private deployment context to understand the
failure mode. That material is intentionally not included here.

Private material must not be committed:

- server keys;
- public/private key files;
- databases;
- service files from a real host;
- logs;
- hostnames;
- IP addresses;
- user names;
- checksums tied only to a private deployment binary;
- process listings;
- runtime paths that identify a private server.

Sanitized technical conclusions that may be documented:

- the target class was Debian 10 Buster on ARMv7/armhf;
- the stock server version involved was RustDesk Server `1.1.16`;
- `hbbs` and `hbbr` were separate services;
- `hbbr` did not require a source change for this issue;
- the observed client error was `Failed to secure tcp: deadline has elapsed`;
- the failure appeared only on the logged-in secure TCP path with a server key
  configured.

Any future issue report should remove private host details before publication.
