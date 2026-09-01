# ADR 0002: Integration test pipeline optimization and FTL quota management

- Status: Accepted
- Date: 2026-09-01

## Context

Integration tests ran on Firebase Test Lab (FTL) on every pull request update via `ci.yml`. This created several operational friction points:

1. **Free-tier quota exhaustion**: Firebase Test Lab's Spark and Blaze free tiers provide 10 virtual device runs per day and 5 physical device runs per day. When developers pushed multiple commits or several PRs were open in a single day, the project quickly exhausted its daily quota, causing builds to fail with quota errors.
2. **Slow PR feedback cycles**: Building debug/instrumentation APKs and executing them on FTL took 20–30 minutes per commit, stalling rapid PR iterations.
3. **Flakiness blocking PR merges**: Intermittent cloud device availability or network timeouts on FTL blocked PR merges because `"Integration Tests"` was a required status check in branch protection.

## Decision

We decouple integration test execution from the mandatory per-commit PR gating pipeline:

1. **Split into dedicated workflow (`.github/workflows/integration-tests.yml`)**:
   - `ci.yml` is streamlined to run only static analysis, unit/widget tests, and coverage ratchet checks (~1–2 minutes).
   - `integration-tests.yml` handles building test APKs, WIF authentication, and Firebase Test Lab execution.
2. **Nightly scheduled cadence (`0 3 * * *`)**:
   - Integration tests run automatically once per day at 3 AM UTC on `main` (staggered with the 2 AM UTC Robo test), using at most 1 test run per day (~30/month) and staying well within the 10 runs/day free tier.
3. **On-demand PR label (`ci:integration-test`) + `workflow_dispatch`**:
   - Developers can opt-in to running full integration tests on high-risk PRs by applying the `ci:integration-test` label or triggering the workflow manually in GitHub Actions.
4. **Branch protection update**:
   - Removed `"Integration Tests"` from required status checks in `.github/rulesets/main-branch-protection.json`. PR merge criteria remain unit/widget tests + coverage ratchet and conventional commit PR titles.

## Alternatives considered

| Alternative | Why we passed |
| --- | --- |
| **Status quo (FTL on every PR commit)** | Exhausts FTL free tier limits in minutes on active development days; adds 25m turnaround to every PR. |
| **GHA headless Android Emulator (`reactivecircus/android-emulator-runner`) on every PR** | Free from Firebase limits, but Linux GHA runners lack hardware acceleration, making boot and test execution slow (~15–20 minutes), fragile, and prone to runner timeouts. |
| **Run only on push to `main` (no nightly)** | On days with zero merges, no regression checks run; on days with many merges, quota can still spike. A nightly cron guarantees consistent daily verification with deterministic quota consumption. |

## Consequences

### Positive
- **Guaranteed free-tier compliance**: Nightly execution (1 run/day) consumes only ~10% of daily free virtual device quota.
- **Lightning-fast PRs**: PR CI turnaround drops from ~25 minutes to ~1–2 minutes.
- **On-demand coverage**: Full integration suite remains accessible for risky PRs simply by adding the `ci:integration-test` label.
- **Unblocked merge queue**: Transient cloud test lab flakiness no longer blocks low-risk PR merges.

### Negative
- Integration test regressions introduced by merged PRs are caught on a 24-hour cycle rather than at pre-merge gate (mitigated by comprehensive unit/widget test coverage ratchet and on-demand PR testing).

### Reversibility
- Re-enabling PR integration tests is a one-line label or workflow trigger change.
