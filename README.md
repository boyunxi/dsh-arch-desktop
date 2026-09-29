# dsh-arch-desktop

A personal Arch Linux package repository for the DeepSeek Harness desktop
application and related packages.

## Layout

```
x86_64/            repository database, served by GitHub Pages
packages/          package bodies, uploaded as GitHub Release assets
scripts/           build and maintenance helpers
pacman.conf.d/     client configuration snippet
```

The split between `x86_64/` and `packages/` is deliberate. GitHub rejects any
file above 100 MB pushed to a normal repository, and these packages are ~350 MB,
so package bodies can only travel as Release assets. The database is small
(kilobytes) and does belong in git.

## Client setup

Add the snippet in `pacman.conf.d/` to `/etc/pacman.conf`, replacing `USERNAME`
with the owning GitHub account:

```ini
[dsh-arch-desktop]
Server = https://USERNAME.github.io/dsh-arch-desktop/x86_64
SigLevel = Optional TrustAll
```

Then:

```sh
sudo pacman -Syu
sudo pacman -S deepseek-harness-desktop
```

## Publishing a package

1. Build the package (see the project's own PKGBUILD).

2. Add it to the repository. This copies the artifact into `packages/`,
   rewrites the database, and materializes the `.db`/`.files` convenience
   names (repo-add creates symlinks, which GitHub Pages does not serve):

   ```sh
   ./scripts/repo-add-pkg.sh /path/to/foo-1.0-1-x86_64.pkg.tar.zst
   ```

3. Confirm every recorded package body is present and its checksum matches:

   ```sh
   ./scripts/repo-verify.sh
   ```

4. Commit the database:

   ```sh
   git add x86_64/
   git commit -m "Add foo 1.0-1"
   git push
   ```

5. Upload the package body as a Release asset, tagged with the same version:

   ```sh
   gh release create foo-1.0-1 \
     packages/foo-1.0-1-x86_64.pkg.tar.zst \
     --title "foo 1.0-1" \
     --notes "foo 1.0-1"
   ```

   Pacman resolves package bodies by filename against the release-asset URL
   recorded in the database, so the tag name is cosmetic — but keeping it equal
   to the package version makes the release list readable.

## Why pagure or a plain directory is not enough

Pacman consults a repository database rather than a directory listing. Dropping
a `.pkg.tar.zst` next to the others changes nothing until `repo-add` rewrites
the database that points at it.

## Why unsigned

Signing would require every client to import and trust a key before the first
`pacman -Syu`. For a repository holding only self-built packages used on
machines already under the same control, `SigLevel = Optional TrustAll` is the
chosen tradeoff. Revisit if this repository ever serves machines the owner does
not administer.

## Adding a second package

Nothing in the flow is specific to one package. Run `repo-add-pkg.sh` for the
new artifact, verify, commit the database, and create a release for the new
body. Every package shares the single `dsh-arch-desktop` database.
