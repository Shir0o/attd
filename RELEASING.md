# Releasing the Attendance Tracker

This document describes the one-click release pipeline that ships Android
APK + AAB artifacts to GitHub Releases and to the Google Play Console
**internal testing** track. Production promotion remains a manual step in
the Play Console UI.

For the rationale behind each choice (release-please vs. alternatives,
internal-track-first, Play App Signing, etc.) see
[`docs/adr/0001-release-automation.md`](docs/adr/0001-release-automation.md).

## How a release happens

1. A conventional-commit PR (e.g. `feat:`, `fix:`) lands on `main`.
   The title carries the conventional-commit signal — release-please
   reads **PR titles**, not commit messages.
2. The `.github/workflows/release-please.yml` workflow opens or updates a
   **release PR**. The PR bumps `pubspec.yaml`, regenerates `CHANGELOG.md`,
   and proposes the next `versionName+versionCode` (e.g. `1.3.3+25`).
3. You review the release PR (check the changelog draft and the version
   bump), then merge it.
4. The merge pushes a tag (e.g. `v1.3.3+25`). The
   `.github/workflows/release.yml` workflow fires:
   - Assembles `key.properties` from secrets.
   - Builds a signed AAB and a signed APK.
   - Attaches both to the GitHub Release for the tag.
   - Uploads the AAB to the Play Console internal testing track via
     `fastlane play_upload`.
5. **You** open the Play Console, verify the AAB on the internal track,
   and click **Promote release → Production** when ready.

That's the whole flow. There is no manual version bump, no manual tag,
no manual upload.

## PR title conventions (required)

The lint workflow `.github/workflows/pr-title-lint.yml` rejects PRs whose
titles don't match a conventional-commit prefix. Allowed prefixes:

| Prefix            | Effect                                |
| ----------------- | ------------------------------------- |
| `feat:`           | Minor bump; lands under "Features"    |
| `feat!:`          | Major bump; lands under "Features"    |
| `fix:`            | Patch bump; lands under "Bug Fixes"   |
| `perf:`           | Patch bump; lands under "Performance" |
| `refactor:`       | No bump; lands under "Refactoring"    |
| `docs:`, `test:`, `build:`, `ci:`, `chore:`, `revert:` | Hidden from changelog (still allowed) |

`BREAKING CHANGE:` in the PR body footer also triggers a major bump.

## Prerequisites (one-time setup)

The pipeline needs six GitHub secrets. None of them are committed; create
them under **Settings → Secrets and variables → Actions**:

| Secret                  | Purpose                                                                 |
| ----------------------- | ----------------------------------------------------------------------- |
| `ANDROID_KEYSTORE_BASE64` | `base64` of the CI **upload** keystore (`upload-key.keystore`).         |
| `KEY_ALIAS`             | Alias of the upload key inside the keystore.                            |
| `KEY_PASSWORD`          | Password for the upload key.                                            |
| `STORE_PASSWORD`        | Password for the keystore file itself.                                  |
| `PLAY_SUPPLY_JSON_KEY`  | Contents of the Play Console service-account JSON (release-manager).    |
| `RELEASE_PLEASE_TOKEN`  | PAT with `contents: write` and `pull-requests: write`. Optional — release-please falls back to `GITHUB_TOKEN` for single-repo PRs, but a PAT avoids the default-token's per-job permission cap and is required for fork PRs. |

### Generating the CI upload keystore

The CI uses a **separate upload key** from your local one (Play App Signing
holds the actual app-signing key on Google's side). Generate it once:

```bash
keytool -genkey -v \
  -keystore ~/upload-key.keystore \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then register it as the upload key in the Play Console under
**Setup → App signing → Upload key reset** (one-time migration; irreversible
without a Play Console support ticket). After enrollment, base64-encode the
keystore file and store it as `ANDROID_KEYSTORE_BASE64`:

```bash
base64 -i ~/upload-key.keystore | tr -d '\n'
# paste the output as the secret value
```

### Generating the Play Console service-account JSON

1. Open Google Cloud Console → IAM & Admin → Service Accounts.
2. Create a service account with the **Release Manager** role on the
   Play Console project.
3. Create a JSON key, download it, paste its contents as the
   `PLAY_SUPPLY_JSON_KEY` secret value.

## Troubleshooting

| Symptom                                                | Likely cause                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| Release-please bot doesn't open a release PR           | No conventional-commit PR titles since the last release.      |
| Release PR bumps `versionName` but not `versionCode`   | `pubspec.yaml` `version:` is malformed — must be `X.Y.Z+N`.   |
| `release.yml` fails on secret check                    | One of the six secrets is empty/missing in repo settings.     |
| `flutter build appbundle` fails with "Supplied proguard configuration does not exist" | `android/app/proguard-rules.pro` was deleted. Restore it.    |
| Play Console upload fails with "versionCode not higher than previous" | The release PR was merged without an actual version bump — the previous tag has the same `versionCode`. Cancel the upload, fix the PR, re-tag. |
| Play Console upload fails with "package not found"     | The applicationId in `android/app/build.gradle.kts` does not match the Play Console listing. Update the Fastfile `APP_PACKAGE_NAME` to match. |
| `bundle exec fastlane play_upload` fails to install    | Ruby/Bundler missing on the runner — the workflow installs them via `bundle install`. If your fork uses an older Ubuntu image, the system Ruby may be too old; pin `ruby-version: 3.2` in `release.yml`. |
| Internal-track upload succeeds but AAB is wrong        | Play Console internal track allows removal — go to Release management → Internal testing, find the version, click **Discard**. Re-run the workflow with the corrected tag. |

## Rolling back a release

- **GitHub Release**: delete the tag (`git push --delete origin v1.3.3+25`
  + delete the release UI). The release-please bot will not re-cut it.
- **Play Console internal track**: discard the release in the Play
  Console UI. No app-store review, takes effect immediately.
- **Play Console production**: use the Play Console "Halt rollout" button.
  This stops the rollout but the version stays in the Play listing until
  you disable it.

## Pre-release tags

A tag matching `*-rc*` or `*-beta*` (e.g. `v1.4.0-rc1+27`) still builds
APK + AAB and attaches them to a GitHub pre-release, but **skips** the
Play Console upload. Use this for external testers who sideload.

## Local equivalent

If you need to ship a one-off from your laptop (without waiting for CI):

```bash
flutter build appbundle --release   # uses your local android/key.properties
flutter build apk --release
# Then upload the AAB manually in the Play Console UI.
```

The CI pipeline is the **canonical** path; the local equivalent is only
for emergencies.