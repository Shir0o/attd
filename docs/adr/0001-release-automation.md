# ADR 0001: Android release automation pipeline

- Status: Accepted
- Date: 2026-08-31
- Context: <https://github.com/Shir0o/attd/issues/146>

## Context

The repo's CHANGELOG.md tracked versions up to `1.3.2` but only one
GitHub Release (`v1.0.9`, 2026-03-15) had ever been cut. Releasing was
fully manual: maintainer bumped `pubspec.yaml` by hand, built locally,
uploaded to Play Console by hand, cut a tag by hand, wrote release notes
by hand. Releases were a half-day of bespoke work and a one-step-away
disaster every time.

## Decision


We adopt a release pipeline built from four pieces:

1. **release-please** as the single source of truth for versioning,
   CHANGELOG generation, tag pushing, and GitHub Release creation.
2. **fastlane supply** for Play Console uploads.
3. **Play App Signing** for keystore management — CI uses a fresh
   upload key, Google holds the app-signing key.
4. **Internal-track-first** delivery — automated uploads land on the
   internal testing track; production promotion stays a manual click.

Release-please reads **PR titles** (not commit messages) as the
conventional-commits signal; squashed merges onto `main` keep the PR
title as the merge commit subject. PR title lint enforces the format
on every opened/edited/synchronize PR event.

## Alternatives considered

### Versioning

| Alternative                | Why we passed                                                                                  |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| Manual `pubspec.yaml` bump | The status quo. Single point of failure; release notes drift from reality; nothing's enforced. |
| `standard-version`         | Reads commit messages, not PR titles; doesn't cut a GitHub Release or Play Console upload.     |
| `release-it`               | More opinionated than release-please, less GitHub-native; no managed `release-please-action`.  |
| `semantic-release`         | Same issues as `standard-version` — commit-message-driven, no GitHub Release or Play integration. |

release-please wins because: (a) it's maintained by Google; (b) it
natively targets the GitHub Release + changelog workflow we need;
(c) PR-title-driven fits this repo's squashed-merge policy.

### Play Console upload

| Alternative                  | Why we passed                                                            |
| ---------------------------- | ------------------------------------------------------------------------ |
| Manual Play Console upload   | The thing we're trying to delete.                                        |
| Firebase App Distribution    | Not a Play Store delivery channel — different distribution model.         |
| `gh action-google-play-upload` | Less flexible than fastlane; community-maintained, narrower scope.        |
| Direct `curl` to Play API    | Reinventing fastlane; loses retry, metadata, and release-status handling. |

fastlane supply is the Google-recommended path, has built-in retry and
release-status semantics, and survives version upgrades without code
changes.

### Keystore management

| Alternative                              | Why we passed                                                                       |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| Commit the keystore to the repo          | Catastrophic once the repo is forked or mirrored. Non-starter.                      |
| Encrypt-and-commit the keystore          | Adds complexity; once any contributor gets the key, you can't take it back.         |
| Local keystore in CI, not stored at all  | Requires a maintainer-present build per release; breaks the "one click" goal.      |
| **Play App Signing (chosen)**             | Upload key (held in CI) signs the AAB; Google's app-signing key (held by Google) is what users get. Losing the upload key = generate a new one, enroll via Play Console reset, no permanent lockout. |

Play App Signing is already enrolled on this app, so the migration cost
was zero.

### Production promotion

| Alternative                          | Why we passed                                                                       |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| Auto-promote to production           | A bad release ships to real users with no human in the loop. Not acceptable.        |
| **Internal-track-first (chosen)**     | Automation does the heavy lifting; the one irreversible click (promote) is human. |
| Staged rollout via fastlane          | Still requires a human review of the AAB; internal-track-first achieves the same gate with simpler tooling. |

Internal-track-first is "fail-safe by default": an internal track
release has no users, can be discarded in one click, and gives the
maintainer a Play-Console-UI preview before promotion.

## Consequences

### Positive

- Releasing is one click after the conventional-commit PR merges.
- Version numbers, changelogs, tags, and Play Console uploads are
  consistent across releases.
- Adding a new commit type to `release-please-config.json` is a
  one-line change reviewed by the config unit test
  (`test/tool/release_please_config_test.dart`).
- The local keystore (`~/.keystores/my-key.keystore`) is no longer a
  single point of failure — losing it doesn't lock the app out of the
  Play Store.

### Negative

- Six new GitHub secrets to provision and rotate. Documented in
  `RELEASING.md` but not auto-rotated.
- Conventional-commits discipline is now required on PR titles (was
  optional). Contributors who write freeform titles will see the
  `pr-title-lint` workflow reject their PRs until they fix the title.
- The CI upload key, once enrolled on the Play Console, cannot be
  rotated without a Play Console "Upload key reset" ticket.
- Adding `release-please` and `fastlane` to the toolchain means two
  more dependencies to track for security updates.

### Reversibility

- **Easy**: the PR title lint, the release-please config, the Fastfile,
  and the release-please bot workflow are all removable in one commit.
- **Medium**: the release.yml workflow is removable but leaves behind
  orphan tags/releases on GitHub.
- **Hard**: the Play App Signing enrollment is irreversible without a
  Play Console support ticket. We've already paid this cost (enrollment
  predates this ADR); this ADR records the choice but does not create
  the irreversibility.
- **Hardest**: the `RELEASE_PLEASE_TOKEN` PAT and the `PLAY_SUPPLY_JSON_KEY`
  service-account JSON, once issued, retain access to the repo and
  Play Console respectively until manually revoked. Rotate by deleting
  the secrets in GitHub settings.

## References

- Spec: <https://github.com/Shir0o/attd/issues/146>
- release-please config: [`release-please-config.json`](../release-please-config.json)
- Release workflow: [`.github/workflows/release.yml`](../.github/workflows/release.yml)
- Release-please bot: [`.github/workflows/release-please.yml`](../.github/workflows/release-please.yml)
- PR title lint: [`.github/workflows/pr-title-lint.yml`](../.github/workflows/pr-title-lint.yml)
- fastlane config: [`fastlane/Fastfile`](../fastlane/Fastfile)
- Operate it: [`RELEASING.md`](../RELEASING.md)