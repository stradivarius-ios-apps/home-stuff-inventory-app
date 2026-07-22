# Public Repository Trust Boundary

The fixed canonical source is
`stradivarius-ios-apps/home-stuff-inventory-app`. It is the only origin for product
changes and hotfixes. All public-repository workflows run on GitHub-hosted runners
with read-only default permissions and no signing or private-release access.

```text
public pull request -> protected public main -> protected release tag + exact SHA
    -> private provenance preflight -> isolated temporary checkout -> sign/upload
```

Signing, export, and explicitly authorized TestFlight upload occur only in the
current private repository, `stradivarius-ios-apps/home-stuff-inventory`. Before a
self-hosted job can run public source, its GitHub-hosted preflight must verify the
fixed repository identity, a full immutable commit SHA on public `main`, a protected
release tag resolving exactly to that SHA, and all required hosted checks for that
SHA. The signing-capable job builds only an isolated detached checkout of the
verified public commit and removes it on every exit path.

There is no mirror branch, bidirectional synchronization, periodic copy, bot sync
pull request, or private-origin product fix. The retained application tree in the
private repository is historical and cannot be selected as a release input.

Public workflows must never use a self-hosted runner, signing secret, private release
environment, release cache, or credential with access to the private repository.
Fork pull requests receive hosted validation only, read-only permissions, no secrets,
and no release capability. Any future automatic public-to-private dispatch requires
a separate threat review and may not place a broad private credential in public.

Vulnerabilities, credentials, private keys, tokens, private user data, exploit
details, private host paths, and runner or signing internals must not be disclosed on
public GitHub surfaces. `SECURITY.md` defines the private reporting route.
