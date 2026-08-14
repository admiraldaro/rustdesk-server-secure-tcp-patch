# Publishing Checklist

Recommended repository slug:

```text
rustdesk-server-secure-tcp-patch
```

Before the first push:

1. Review [NOTICE.md](NOTICE.md) and keep the unofficial disclaimer.
2. Confirm the GitHub owner and repository links use `admiraldaro`.
3. Confirm no generated files are staged:

   ```sh
   git status --short --ignored
   ```

4. Confirm only source-patch material is tracked:

   ```sh
   git add --dry-run .
   ```

5. Do not commit `work/`, `dist/`, `release-assets/`, `hbbs`, `hbbr`, keys,
   logs, service files, or databases.
6. Create the GitHub repository separately from Rust-Book.
7. Push this repository only after reviewing the staged file list.

Suggested first commit:

```sh
git add .
git commit -m "Add secure TCP hbbs source patch"
git remote add origin https://github.com/admiraldaro/rustdesk-server-secure-tcp-patch.git
git push -u origin main
```

## Release Assets

Release assets are staged locally under:

```text
release-assets/0.1.0/
```

That directory is ignored by Git. It is for manual GitHub Release uploads only,
not ordinary Git history.

Required `0.1.0` assets:

```text
hbbs-1.1.16-secure-tcp-armv7-linux
hbbs-1.1.16-secure-tcp-armv7-linux.sha256
hbbs-1.1.16-secure-tcp-armv7-linux.tar.gz
rustdesk-server-1.1.16-secure-tcp-source.tar.gz
rustdesk-server-1.1.16-secure-tcp-source.tar.gz.sha256
BUILDINFO.txt
SOURCE-OFFER.txt
RELEASE-NOTES.md
```

Do not upload compiled binaries unless the matching Corresponding Source asset
is uploaded with the same release.

## GitHub Web Release

1. Commit and push the source repository.
2. Create tag `v0.1.0`.
3. Create a GitHub Release from that tag.
4. Use `release-assets/0.1.0/RELEASE-NOTES.md` as the release notes.
5. Upload every prepared release asset.
6. Confirm the source archive and binary are both visible.
7. Download the published assets into a temporary directory.
8. Verify checksums after download.
9. Publish the release only after the checksums match.

## GitHub CLI Template

PowerShell:

```powershell
gh release create v0.1.0 `
  "release-assets/0.1.0/hbbs-1.1.16-secure-tcp-armv7-linux" `
  "release-assets/0.1.0/hbbs-1.1.16-secure-tcp-armv7-linux.sha256" `
  "release-assets/0.1.0/hbbs-1.1.16-secure-tcp-armv7-linux.tar.gz" `
  "release-assets/0.1.0/rustdesk-server-1.1.16-secure-tcp-source.tar.gz" `
  "release-assets/0.1.0/rustdesk-server-1.1.16-secure-tcp-source.tar.gz.sha256" `
  "release-assets/0.1.0/BUILDINFO.txt" `
  "release-assets/0.1.0/SOURCE-OFFER.txt" `
  --title "0.1.0 - ARMv7 tested build" `
  --notes-file "release-assets/0.1.0/RELEASE-NOTES.md"
```

Do not run this command until the GitHub repository exists and the source commit
and tag are ready.
