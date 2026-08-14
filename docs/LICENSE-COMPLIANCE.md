# License Compliance

This repository is licensed under the GNU Affero General Public License version
3 because it contains a patch for AGPL-licensed RustDesk Server source.

This is practical project guidance, not legal advice.

## Repository Contents

Included:

- source patch files;
- helper scripts;
- source manifest;
- build and test documentation;
- AGPL license text.

Not included in normal Git history:

- compiled `hbbs` or `hbbr` binaries;
- RustDesk Server keys;
- private deployment logs;
- databases;
- host-specific service files.

Optional GitHub Release assets may include a prebuilt patched `hbbs` binary.
Those release assets must be accompanied by the matching Corresponding Source
archive and AGPL notices.

## If You Publish This Repository

Keep:

- [LICENSE](../LICENSE)
- [NOTICE.md](../NOTICE.md)
- [SOURCE_MANIFEST.md](../SOURCE_MANIFEST.md)
- patch provenance pointing to upstream PR #691
- clear language that this is unofficial and not endorsed by RustDesk

Do not describe the project as an official RustDesk Server release.

## If You Distribute A Binary

If you distribute a patched `hbbs` binary, provide the corresponding source for
that exact binary. At minimum, provide:

- upstream RustDesk Server commit;
- this repository commit;
- exact patch files;
- build instructions;
- build scripts or equivalent commands;
- dependency patch details, if used;
- license notices.

For the `0.1.0` ARMv7 binary, the matching source asset is:

```text
rustdesk-server-1.1.16-secure-tcp-source.tar.gz
```

## If You Run The Modified Network Server

AGPL has network-use source obligations. If users interact with a modified
network server, make the corresponding modified source available in the manner
required by the AGPL.

## Rust-Book Separation

Rust-Book is a separate PHP API/address-book project:

```text
https://github.com/admiraldaro/rust-book
```

Keep this patch project separate unless you intentionally want an AGPL patch
directory inside another repository with clear notices.

The recommended publication model is a separate repository for this patch.
