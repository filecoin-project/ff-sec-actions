# Proposal

## Why

`ff-sec-actions` has a working security-gate platform, but its behavior lives only in prose reference docs, a decision map, and `roadmap/state.json`. Nothing ties a claimed behavior to the code or test that proves it. These sources have already drifted apart: profile detection shipped while PROF-01 and PROF-02 still read `pending`. Moving to OpenSpec now gives each verified behavior one durable home before the profile and Merge Gate work grows the surface further.

## What Changes

- Adopt OpenSpec as the source of truth for **what the platform does** (specs) and **work in flight** (changes).
- Scope the platform to **security gates only**. Code quality evaluations (lint, coverage, fuzzing, builds) are out of scope, so the Ecosystem Baseline promise not to execute project code stays unchanged.
- Backfill baseline specs for nine capabilities that are already built. Each requirement describes current behavior and points to the code or test that proves it. Planned behavior is excluded.
- Give the Merge Gate its own capability, separate from evidence aggregation, because gate decisions are the main thing consumers adopt.
- Shrink `roadmap/state.json` to ordering, dependencies, and release gates G0–G4. Each task links to the OpenSpec change that delivers it. Task status comes from the change lifecycle, so it is no longer recorded twice.
- Freeze `docs/ECOSYSTEM-SECURITY-DECISION-MAP.md` as history. Open decisions are settled in the `design.md` of the change that claims them.
- Reconcile the profile-detection drift from evidence: PROF-02 closes only if its acceptance criteria are shown to hold.
- Set `openspec/config.yaml` project context so artifacts use the `CONTEXT.md` vocabulary and the security-gate scope.

## Capabilities

### New Capabilities

- `execution-trust`: Execution trust tiers, least-privilege permissions, safe checkout, no package lifecycle execution, and fork pull-request safety.
- `release-integrity`: Cross-organization distribution model and consumer pins that immutably cover the whole transitive execution graph.
- `evaluation-result`: The normalized Evaluation Result schema and Completion Status semantics, independent of finding severity.
- `evaluation-adapter`: The contract that turns a scanner's raw output and exit behavior into an Evaluation Result (gitleaks, zizmor, semgrep).
- `evidence-bundle`: Aggregation of Evaluation Results into one Evidence Bundle with coverage and a profile conclusion.
- `merge-gate`: Consumer-selected policy that turns results and Completion Statuses into a merge-blocking decision, where incomplete evaluation never reads as a pass.
- `consumable-output`: Outputs, artifacts, and summaries every reusable workflow and composite action must expose to Consumer Projects.
- `profile-detection`: Detection of Filecoin Security Profiles from repository signals, including explicit coverage gaps for unrecognized components.
- `ecosystem-baseline`: The secretless, read-only evaluations that run safely on any Consumer Project pull request today.

### Modified Capabilities

None. No specs exist yet.

## Impact

- **New:** `openspec/specs/*` for the nine capabilities (created when this change is archived); `openspec/config.yaml` project context.
- **Changed:** `roadmap/state.json` schema (task-to-change link, status from change lifecycle), `scripts/roadmap.sh`, `scripts/test-roadmap.sh`, `scripts/check-docs.sh`, and the `docs.yml` and `g0-contract.yml` workflows that enforce them.
- **Changed:** `roadmap/README.md`, `docs/ECOSYSTEM-SECURITY-DECISION-MAP.md` (marked frozen), and maintainer docs that describe the planning process.
- **Changed:** `actions/aggregate-results` no longer marks bundle totals authoritative when a required evaluation is missing. Consumers receive this at the next reviewed pin advance (see design Decision 9).
- **No change** to workflow or action inputs and outputs, or to current pins.
