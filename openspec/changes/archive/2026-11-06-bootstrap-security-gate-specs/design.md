# Design

## Context

See proposal.md for why. Three facts shape the approach:

- `roadmap/state.json` (schema v1) records a `status` per task. `scripts/roadmap.sh` validates and mutates it, `scripts/test-roadmap.sh` tests it, and both `g0-contract.yml` and `docs.yml` run those tests. `scripts/check-docs.sh` requires the state file and the decision map to exist.
- Each capability already has a human-readable reference page under `docs/reference/` and one or more `scripts/check-*.sh` / `scripts/test-*.sh` suites. The specs in this change were drafted from those pages and the action and workflow source.
- Some spec scenarios are stated in docs but have no rejecting test yet (see Decision 2).

## Goals / Non-Goals

**Goals:**
- After archive, `openspec/specs/` holds nine capability specs whose every scenario is proven by a check, test, or fixture.
- Each fact has exactly one home: behavior in specs, in-flight work in changes, ordering and gates in `state.json`.
- Existing CI enforcement of the roadmap keeps working through the schema change.

**Non-Goals:**
- No workflow or action input, output, or pin changes. The only behavior change is the bundle-authority fix in Decision 9.
- No new security evaluations or profile composition. The remaining BASE-01 and PROF-02 work moves to their own changes.
- No generated reference documentation (DOC-01 stays separate).

## Decisions

### 1. Bootstrap through one archived change

This change carries all nine capabilities as ADDED deltas and is archived once verified, so `openspec archive` creates `openspec/specs/`.

*Alternative:* hand-write `openspec/specs/` directly. Rejected because it leaves no proposal or design recording why the specs say what they say, and it bypasses validation on the way in.

### 2. Every scenario must be proven before archive

A scenario stays in a spec only if a check, test, or fixture proves it. The proof map below is the verification checklist for tasks.md. Where no proof exists, the implementer either adds a narrow test that exercises current behavior (no behavior change) or removes the scenario before archive. Specs never keep an unproven claim.

| Capability | Proof |
|---|---|
| execution-trust | `check-execution-trust.sh`, `check-workflow-security.sh` + `test-workflow-security.sh`, `check-baseline-no-exec.sh` + `test-baseline-no-exec.sh`, `check-fork-pr.sh` + `test-fork-pr.sh` |
| release-integrity | `check-release-graph.sh` + `test-release-graph.sh`; checksum verification in `test-gitleaks-scan.sh`, `test-zizmor-scan.sh` |
| evaluation-result | `check-evaluation-result.sh` + `test-evaluation-result.sh`, `test/fixtures/evaluation-result/` |
| evaluation-adapter | `test-evaluation-adapter.sh`, `test-scanner-outcome.sh`, `check-scanner-gates.sh`, scanner leaf tests |
| evidence-bundle | `test-aggregate-results.sh` |
| merge-gate | `test-aggregate-results.sh`, `test-evaluation-adapter.sh`, `test-ecosystem-baseline.sh` |
| consumable-output | `check-output-contract.sh` + `test-output-contract.sh` |
| profile-detection | `test-detect-filecoin-profile.sh`, `test/fixtures/profile-detection/` |
| ecosystem-baseline | `test-ecosystem-baseline.sh`, `test-fork-pr.sh`, `test-consumer-alpha.sh` |

Gaps found during drafting and how each was resolved:

| Gap | Resolution |
|---|---|
| merge-gate: `require-complete: false` relaxes a skip; zero results fail | Proven: `skipped-relaxed` and `no-results` cases in `test-aggregate-results.sh` |
| consumable-output: 20-finding cap; secret redaction | Proven: `many-findings` case in `test-evaluation-adapter.sh`; planted-value check in `test-gitleaks-scan.sh` |
| ecosystem-baseline: Consumer Project Semgrep configuration ignored | Narrowed: proven for a planted `.semgrep.yml`. `.semgrepignore` and inline `nosemgrep` are honored, so they are excluded from the spec and documented as a known limitation (Decision 9) |
| evaluation-result: older consumers never receive newer minor fields | Removed: no producer lets a consumer select a version. Replaced by "earlier supported versions remain valid", proven by the 1.0.0 fixtures |
| release-integrity: rollback by changing one SHA | Removed: follows from full pinning and is not separately testable. Replaced by example-pin rejection proven in `test-consumer-alpha.sh` |
| evidence-bundle: totals authoritative over missing coverage | Defect fixed in this change (Decision 9) |

Every requirement's scenarios share the proof listed for that requirement:

| Capability | Requirement | Proof |
|---|---|---|
| execution-trust | Every surface is classified | `check-execution-trust.sh` |
| execution-trust | Baseline inspects but never executes | `check-baseline-no-exec.sh`, `test-baseline-no-exec.sh` |
| execution-trust | Narrowest explicit permissions; checkout never persists credentials | `check-workflow-security.sh`, `test-workflow-security.sh` |
| execution-trust | Execution never holds authority | `check-execution-trust.sh` (release-allowed tier contract) |
| execution-trust | Fork PRs run without authority; privileged triggers forbidden | `check-fork-pr.sh`, `test-fork-pr.sh` |
| release-integrity | One full commit SHA | `test-consumer-alpha.sh`, `check-release-graph.sh` |
| release-integrity | Pin covers the transitive graph; exact tool versions | `test-release-graph.sh` (mutable ref, container digest, worktree action, missing asset, missing marker) |
| release-integrity | Every entrypoint receives the guarantee | `security/release-graph.json` entrypoints, `check-release-graph.sh` |
| evaluation-result | Schema, completion, null count, content-addressed evidence, earlier versions valid | `test-evaluation-result.sh`, `test/fixtures/evaluation-result/` |
| evaluation-adapter | Normalizes without executing; exit codes; severity; evidence hash | `test-evaluation-adapter.sh` |
| evaluation-adapter | Scanner leaves conform | `test-zizmor-scan.sh`, `test-gitleaks-scan.sh`, `test-scanner-outcome.sh` |
| evidence-bundle | All requirements | `test-aggregate-results.sh` |
| merge-gate | Per-evaluation conclusions; policy vs operational exits | `test-evaluation-adapter.sh`, `test-aggregate-results.sh` |
| merge-gate | Profile gate, completeness default, per-evaluation gates | `test-aggregate-results.sh`, `test-ecosystem-baseline.sh` |
| consumable-output | Inventory and declared interfaces | `check-output-contract.sh`, `test-output-contract.sh` |
| consumable-output | Required surfaces, bounded presentation, redaction | `test-evaluation-adapter.sh`, `test-gitleaks-scan.sh` |
| profile-detection | All requirements | `test-detect-filecoin-profile.sh`, `test/fixtures/profile-detection/` |
| ecosystem-baseline | Five evaluations, single check, defaults, static rules | `test-ecosystem-baseline.sh` (detection path with `BASELINE_RUN_DETECTION=true`) |
| ecosystem-baseline | No authority or execution | `test-fork-pr.sh`, `check-baseline-no-exec.sh` |
| ecosystem-baseline | Limitations are explicit | `check-output-contract.sh` coverage mapping, `sec-dependencies.yml` limitations |

### 3. `state.json` v2: tasks link to changes, status is derived

Schema version 2 replaces the stored `status` with:

- `change`: `null` or an OpenSpec change name.
- `cancelled`: optional boolean.

`roadmap.sh` derives status from the filesystem without needing the OpenSpec CLI:

```text
cancelled: true                                 -> cancelled
openspec/changes/archive/*-<change>/ exists     -> done
openspec/changes/<change>/ exists               -> in_progress
otherwise, any blocked_by not done              -> blocked
otherwise                                       -> pending
```

The existing invariants remain enforced on derived status: at most one task `in_progress`, a task cannot be claimed until its dependencies are `done`, and a `done` task cannot depend on an unfinished one. `set-status` is replaced by `claim <task-id> <change-name>`, which checks dependencies, writes the link, and requires `ROADMAP_ALLOW_WRITE=true`. Creating the change itself stays an `openspec new change` step.

*Alternative:* keep `status` and add a consistency check against the change. Rejected because two recorded values that must agree is the drift this change removes.

*Alternative:* move ordering and gates into OpenSpec. Rejected because OpenSpec has no dependency or gate model, and the current graph is already tested.

### 4. Historical tasks link to this change

The 16 tasks completed before OpenSpec link to `bootstrap-security-gate-specs`. Archiving this change therefore turns them `done` through the same rule as every future task. Until archive they read `in_progress`, which is accurate: their specs are being verified.

That would put 17 tasks in progress during the migration, and BASE-01 would depend on unfinished tasks. Until archive, a task linked to the bootstrap change therefore counts as `done` for dependency checks and is excluded from the single-in-progress count. The exemption is removed right after this change is archived.

### 5. BASE-01 and PROF-02 reconciliation

- **BASE-01** keeps its remaining acceptance criteria (useful across all supported project types, visible unsupported coverage, full consumable-output mapping). It links to a new scaffolded change, `complete-ecosystem-baseline`, which holds the remaining work. The behavior that ships today is specified here in `ecosystem-baseline`.
- **PROF-02** covers detection *and composition*. Detection is specified here and proven by its fixtures, including `ambiguous-go`, `generic-solidity`, `mixed`, and `unknown-repository`. Composition (running profile evaluations from detection output) does not exist, so PROF-02 stays open with its objective narrowed to composition. Its link to PROF-01 stays because composition needs the finalized taxonomy.
- **PROF-01** stays pending. The catalog defines seven profiles, but none has an owner or coverage statement, which its acceptance criteria require.

### 6. Freeze the decision map

`docs/ECOSYSTEM-SECURITY-DECISION-MAP.md` gains a banner stating that it is frozen history, that answered decisions now live in specs, and that each open ticket is settled in the `design.md` of the change whose task references it through `decision_refs`. Its content is not edited or deleted, so existing links keep working.

### 7. Project context in `openspec/config.yaml`

`context` states the security-gate-only scope, requires the `CONTEXT.md` vocabulary, and requires that spec requirements describe behavior with proof. A `specs` rule requires each new scenario to name or add its proof in the change's design or tasks. Nothing from `CONTEXT.md` is duplicated.

### 8. Validate OpenSpec artifacts in CI

`docs.yml` runs `scripts/check-openspec.sh`, which strictly validates main specs and every active change that has a `proposal.md`. A freshly scaffolded change has no deltas yet, so `openspec validate --all --strict` would fail on legitimate in-flight state; the script reports such a change instead. The CLI is installed at an exact pinned version with lifecycle scripts disabled, inside the existing `control-repository-ci` tier. `security/workflow-policy.json` and `security/execution-trust.json` are updated to record it.

*Alternative:* skip CI validation. Rejected because unvalidated specs drift the same way the roadmap did.

### 9. Defects found while proving the specs

- **Bundle totals over missing coverage (fixed here).** The aggregator marked findings and suppression totals authoritative when a required evaluation was missing or no result arrived, which reports a clean count from no evidence. The aggregator now requires every required evaluation to be received before either total is authoritative. This changes one consumer-visible bundle field, so it reaches Consumer Projects only at the next reviewed pin advance.
- **Consumer-controlled Semgrep exclusions (deferred).** Semgrep honors a scanned repository's `.semgrepignore` and inline `nosemgrep` comments, so a fork pull request can remove coverage while the result reports `complete`. Fixing this changes the pinned scan invocation and the release graph. It is recorded as remaining work for `complete-ecosystem-baseline` and documented as a known limitation in `docs/reference/ecosystem-baseline-rules.md`.

## Risks / Trade-offs

- [Specs overstate behavior that docs claimed but tests never proved] → Decision 2 makes proof a gate for archive. Gaps found while drafting are already listed.
- [The state schema change breaks `roadmap.sh` consumers outside CI] → `roadmap.sh` is only used by this repository. `test-roadmap.sh` gains v2 fixtures covering every derived status and each invariant.
- [17 tasks read `in_progress` until archive] → Scoped by the bootstrap exemption in Decision 4, which is removed when the change is archived.
- [Installing the OpenSpec CLI in CI adds a supply-chain dependency] → Exact version, lifecycle scripts disabled, control-repository CI only, never in a consumer path.
- [Archive renames the change directory with a date prefix] → Derivation matches `archive/*-<change>`, which is OpenSpec's archive layout.

## Migration Plan

1. Write the v2 schema, derivation, and `claim` in `roadmap.sh`, with v2 tests. Convert `state.json`, linking historical tasks and BASE-01.
2. Close the proof gaps from Decision 2.
3. Add project context, the decision-map banner, doc updates, and CI validation.
4. Run every suite in the proof map, plus `openspec validate --all --strict`.
5. Archive this change. Remove the bootstrap exemption and confirm the 16 historical tasks derive `done`.

Rollback: before archive, revert the commits. `state.json` v1 and its scripts are restored together. After archive, specs are additive and can stay even if the roadmap change is reverted.

## Open Questions

- Should the single-in-progress invariant later relax so that independent changes can run in parallel? The current rule is kept, and relaxing it does not change these specs or tasks.
