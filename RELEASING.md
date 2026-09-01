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
   **release PR**. The PR bumps `pubspec.yaml` (bare semver, e.g.
   `1.3.3`) and regenerates `CHANGELOG.md`. The Android `versionCode` is
   derived from the tag by the `release.yml` workflow at build time
   (`major*10000 + minor*100 + patch`, e.g. `v1.3.3` → `10303`).
3. You review the release PR (check the changelog draft and the version
   bump), then merge it.
4. The merge pushes a tag (e.g. `v1.3.3`). The
   `.github/workflows/release.yml` workflow fires:
   - Assembles `key.properties` from secrets.
   - Derives the `versionCode` from the tag.
   - Builds a signed AAB and a signed APK with `--build-number=$vc`.
   - Attaches both to the GitHub Release for the tag.
   - Uploads the AAB to the Play Console internal testing track via
     `fastlane play_upload` as a **draft** (testers are not
     auto-notified).
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
| `ANDROID_KEYSTORE_BASE64` | `base64` of the CI **upload** keystore. See below.                    |
| `KEY_ALIAS`             | Alias of the upload key inside the keystore.                            |
| `KEY_PASSWORD`          | Password for the upload key.                                            |
| `STORE_PASSWORD`        | Password for the keystore file itself.                                  |
| `PLAY_SUPPLY_JSON_KEY`  | Contents of the Play Console service-account JSON (release-manager).    |
| `RELEASE_PLEASE_TOKEN`  | PAT with `contents: write` and `pull-requests: write`. Optional — release-please falls back to `GITHUB_TOKEN` for single-repo PRs, but a PAT avoids the default-token's per-job permission cap and is required for fork PRs. |

### Generating / locating the CI upload keystore

Play App Signing is already enabled on this app. The CI signs AABs with
the **upload key** (the key registered on the Play Console); Google's
app-signing key is what Play Store actually serves to users.

The simplest path: reuse the same keystore you already sign manual
builds with locally (`~/.keystores/my-key.keystore` on this machine,
typically). Once it's already registered as the upload key in the Play
Console (which it should be, since you've shipped with it), CI just
needs:

```bash
base64 -i ~/.keystores/my-key.keystore | tr -d '\n' | \
  gh secret set ANDROID_KEYSTORE_BASE64 --repo Shir0o/attd
gh secret set KEY_ALIAS --repo Shir0o/attd --body "my-key-alias"
gh secret set KEY_PASSWORD --repo Shir0o/attd --body "<your-key-password>"
gh secret set STORE_PASSWORD --repo Shir0o/attd --body "<your-store-password>"
```

If you ever want a CI-only upload key, generate a fresh keystore and
enroll it via **Play Console → Setup → App signing → Upload key reset**
(one-time, irreversible without a Play Console support ticket).

### Generating the Play Console service-account JSON

1. Open Google Cloud Console → IAM & Admin → Service Accounts.
2. Create a service account (no GCP-side role needed — Play Console
   manages its own grants).
3. Create a JSON key, download it, paste its contents as the
   `PLAY_SUPPLY_JSON_KEY` secret value:

```bash
gh secret set PLAY_SUPPLY_JSON_KEY --repo Shir0o/attd < ~/path/to/key.json
```

4. In **Play Console → Settings → API access**, link the service
   account and grant it the **Release Manager** permission.

## Troubleshooting

| Symptom                                                | Likely cause                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| Release-please bot doesn't open a release PR           | No conventional-commit PR titles since the last release tag, or all PR titles were `chore:`/`docs:`/`test:`/`build:`/`ci:`/`refactor:` (none trigger a bump). Add a real `fix:` or `feat:` title. |
| `release.yml` fails on secret check                    | One of the six secrets is empty/missing in repo settings.     |
| `flutter build appbundle` fails with "Supplied proguard configuration does not exist" | `android/app/proguard-rules.pro` was deleted. Restore it.    |
| Play Console upload fails with "versionCode not higher than previous" | Two tags have the same `major*10000 + minor*100 + patch`. Don't re-tag without bumping. |
| Play Console upload fails with "package not found"     | The applicationId in `android/app/build.gradle.kts` does not match the Play Console listing. Update the Fastfile `APP_PACKAGE_NAME` to match. |
| Play Console upload fails with "permission denied" / 403 | The service account named in `PLAY_SUPPLY_JSON_KEY` has not been granted Release Manager on the Play Console. Re-link it. |
| `bundle exec fastlane play_upload` fails to install    | Ruby/Bundler missing on the runner — the workflow installs them via `bundle install`. If your fork uses an older Ubuntu image, the system Ruby may be too old; pin `ruby-version: 3.2` in `release.yml`. |
| Internal-track upload succeeds but AAB is wrong        | Play Console internal track allows removal — go to Release management → Internal testing, find the version, click **Discard**. Re-run the workflow with the corrected tag. |

## Rolling back a release

- **GitHub Release**: delete the tag (`git push --delete origin v1.3.3`
  + delete the release UI). The release-please bot will not re-cut it.
- **Play Console internal track**: discard the release in the Play
  Console UI. No app-store review, takes effect immediately.
- **Play Console production**: use the Play Console "Halt rollout" button.
  This stops the rollout but the version stays in the Play listing until
  you disable it.

## Pre-release tags

A tag matching `*-rc*` or `*-beta*` (e.g. `v1.4.0-rc1`) still builds
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