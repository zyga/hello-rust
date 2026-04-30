<!--
SPDX-FileCopyrightText: Canonical Ltd.
SPDX-License-Identifier: Apache-2.0
-->
# Rust Hello World, delivered as a snap

Example repository showing a tasteful **build, test, and publish** pipeline for
a Snap package.

The application itself is intentionally tiny. The interesting part is the
GitHub Actions setup around `snapcraft.yaml`: native build checks,
multi-architecture snap builds, spread-based smoke tests, gated uploads to the
Snap Store, and a separate promotion workflow for moving a tested revision into
a more stable channel.

## Prerequisites

Before copying this pipeline to another project, make sure you have:

1. A **Snap Store account** backed by Ubuntu SSO.
2. A **registered snap name** in the Snap Store.
3. A **local system with `snapcraft` installed** so you can create publishing tokens with `snapcraft export-login`.
4. A working **`snapcraft.yaml`** that defines how the snap is built.
5. An optional **`spread.yaml`** if you want integration or smoke tests in virtual machines.

## Repository layout

| Path                                      | Role                                                                 |
| ----------------------------------------- | -------------------------------------------------------------------- |
| `src/main.rs`                             | Example Rust application.                                            |
| `snapcraft.yaml`                          | Snap packaging definition.                                           |
| `spread.yaml`                             | Optional _spread_ integration tests.                                 |
| `tests/smoke/`                            | Smoke tests executed by spread after the snap is built.              |
| `.github/workflows/build.yml`             | Entry-point workflow for code build and snap pipeline orchestration. |
| `.github/workflows/tasteful-crafts.yml`   | Reusable workflow that builds, tests, and uploads snaps.             |
| `.github/workflows/snapcraft-pack.yml`    | Reusable workflow that builds snap artifacts.                        |
| `.github/workflows/spread.yml`            | Reusable workflow that runs spread-based integration tests.          |
| `.github/workflows/snapcraft-upload.yml`  | Reusable workflow that uploads built snaps to the Snap Store.        |
| `.github/workflows/snapcraft-promote.yml` | Manual promotion workflow for moving revisions between channels.     |

## What the pipeline does

`build.yml` is the top-level workflow:

1. Build and test the Rust project with Cargo.
2. Call `tasteful-crafts.yml`.

`tasteful-crafts.yml` then:

1. Builds snaps for `amd64` and `arm64`.
2. Discovers spread systems at runtime from `spread.yaml` by running
   `spread -list`.
3. Runs spread smoke tests on `amd64`.
4. Uploads the resulting snaps to the Snap Store in a single deployment job.

By default:

- branch builds publish to `latest/edge`
- tag builds publish to `latest/candidate`
- `snapcraft-promote.yml` manually promotes from one channel to another,
  typically `latest/candidate` to `latest/stable`, using the snap name from
  `snapcraft.yaml`

This keeps the fast architecture-independent checks close to every change,
derives the test matrix from the actual spread configuration, uses spread where
virtualisation is reliable, and leaves the stable release step explicit and
reviewable.

## GitHub setup

This example relies on **GitHub environments** for deployment control.

Create environments that match the channel names used by the workflows:

- `latest/edge`
- `latest/candidate`
- `latest/stable`

You can attach approval rules or branch/tag protection rules to those
environments if you want manual gates before publishing or promoting.

For branch builds, `build.yml` uses the repository or organization variable
`SNAPCRAFT_CHANNEL` when it is set; otherwise it falls back to `latest/edge`.
Tag builds always target `latest/candidate`.

## Creating `SNAPCRAFT_STORE_CREDENTIALS`

Create the secret value on a machine where `snapcraft` is installed and
authenticated against your Ubuntu SSO account:

```sh
snapcraft login
snapcraft export-login \
  --snaps=<snap-name> \
  --channels=<snap-store-channel> \
  --acls=package_upload,package_release \
  <token-file>
```

Copy the exported credentials and save them in the matching GitHub environment
as a secret named `SNAPCRAFT_STORE_CREDENTIALS`.

Examples:

- for `latest/edge`, export a token scoped to `--channels=latest/edge`
- for `latest/candidate`, export a token scoped to `--channels=latest/candidate`

For the manual promotion workflow, create another secret value for the target
environment with the permissions needed for promotion:

```bash
snapcraft export-login \
  --snaps=<snap-name> \
  --channels=<target-channel> \
  --acls=package_access,package_release \
  <token-file>
```

Store that value as `SNAPCRAFT_STORE_CREDENTIALS` in the environment whose name
matches the promotion target, such as `latest/stable`.
