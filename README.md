# Ember Builder

This is a fork of [void-builder](https://github.com/voideditor/void-builder) (itself a fork of VSCodium's build pipeline), adapted for building [Aventir Ember](https://github.com/albin-holmgren/Aventir-Ember).

GitHub Actions in this repo clone the Aventir-Ember source, compile it using the VS Code gulp pipeline, and upload the resulting binaries to [albin-holmgren/ember-binaries](https://github.com/albin-holmgren/ember-binaries) as GitHub Releases.

## Companion repos required

| Repo | Purpose |
|------|---------|
| `albin-holmgren/Aventir-Ember` | Source code (already exists) |
| `albin-holmgren/ember-builder` | This repo — runs the build workflows |
| `albin-holmgren/ember-binaries` | Stores built installers (.exe, .dmg, .AppImage) |
| `albin-holmgren/ember-versions` | Version JSON for in-app auto-update |

## Setup

### 1. Fork void-builder

Fork `voideditor/void-builder` into your account as `ember-builder`, then replace:
- `get_repo.sh` and `.github/workflows/stable-*.yml` with the files from this directory.
- All other scripts (build.sh, release.sh, check_tags.sh, etc.) are inherited unchanged from void-builder.

### 2. Create companion repos

Create two **empty** public repos on GitHub:
- `albin-holmgren/ember-binaries`
- `albin-holmgren/ember-versions`

### 3. Add secrets to ember-builder

Go to ember-builder → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `STRONGER_GITHUB_TOKEN` | PAT with `repo` scope (needs write access to ember-binaries and ember-versions) |

macOS signing secrets are optional — skip for initial unsigned builds.

## Triggering a build

Go to Actions → stable-windows (or stable-macos / stable-linux) → Run workflow.

Check **Generate assets** to force a build even if the version hasn't changed.

## Output

Built files land in `albin-holmgren/ember-binaries` as a GitHub Release tagged with the version number from `product.json` (`voidVersion` + `voidRelease`, e.g. `1.4.90044`).
