# App Store Connect metadata baseline

Status: Active public metadata source and validation guide

`fastlane/metadata` is the reviewed source for durable version-localized App Store copy
in `en-GB` and `uk`. The app name is managed separately in App Store Connect: do not add
`name.txt`. Per-release What’s New text is also separate: do not commit
`release_notes.txt`.

Validate locally with:

```sh
ruby .github/scripts/validate_app_store_metadata.rb fastlane/metadata
```

## Public Ownership Boundary

This directory owns only the repository-managed localized metadata files and their
local validation contract. Keep `en-GB` and `uk` values paired, review changes in the
pull request, and run the validator above before merging.

The app name is App Store-managed and per-release What’s New text belongs to the
release process, so neither is part of this metadata directory.

Credentialed comparison with App Store Connect, publication, verification, and
recovery are maintainer-only operations in a separate private release control plane.
Credentials and private operational details do not belong in this public repository.
