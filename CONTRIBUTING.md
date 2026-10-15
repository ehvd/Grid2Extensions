# Contributing

## Git flow

| Branch | Purpose |
|---|---|
| `main` | Released code only. Every commit on `main` is a tagged release. |
| `develop` | Integration branch (GitHub default). |
| `feature/<issue>-<slug>` | From `develop`, merged back via PR. |
| `release/x.y.z` | From `develop`; merged to `main`, tagged `vx.y.z`, merged back to `develop`. |
| `hotfix/x.y.z` | From `main`; same as release. |

With the `git flow` CLI (`git flow init -d` has been run on the project):

```bash
git flow feature start 12-message-templates      # branch feature/12-message-templates
git push -u origin feature/12-message-templates  # open a PR into develop

git flow release start 0.1.0
# bump CHANGELOG.md, then:
git flow release finish -m "v0.1.0" 0.1.0        # merges to main, tags v0.1.0, merges back
git push origin main develop --tags
```

Without the CLI: `git checkout -b feature/12-x develop`; for releases
`git checkout -b release/0.1.0 develop`, then merge `--no-ff` into `main`, tag `v0.1.0`,
and merge `--no-ff` back into `develop`.

`main` and `develop` are protected: changes go through a PR with passing CI. No force pushes.

## Rules

- One issue → one feature branch → one PR into `develop` with `Closes #N`.
- Update `[Unreleased]` in `CHANGELOG.md` in every PR.
- `make lint` (`luacheck .`) must pass locally before pushing; `make install` or `make link` put the addon into your AddOns folder (see the README).
- Never commit `Libs/` or any secret.

## Commit conventions

[Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`;
optional scope, e.g. `feat(scanner): slice queries by level`.

## Release tags

`v1.2.3` → release, `v1.2.3-beta.1` → beta, `v1.2.3-alpha.1` → alpha (CurseForge + GitHub Release).

## Releasing

1. Cut `release/x.y.z` from `develop`: turn `[Unreleased]` in `CHANGELOG.md` into a dated section and fix the compare links at the bottom.
2. PR into `develop`, wait for the `luacheck` check, squash-merge.
3. Fast-forward `main` to the merged `develop` commit and tag `vx.y.z`; the Release workflow uploads the file to CurseForge and GitHub.
