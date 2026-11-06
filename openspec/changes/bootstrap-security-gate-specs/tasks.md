# Tasks

## 1. Roadmap state v2

- [x] 1.1 Extend `scripts/roadmap.sh` validation to accept schema version 2: a nullable `change` field and an optional `cancelled` boolean in place of the stored `status`, and the v2 shape of `started_at`/`completed_at` if retained. Verify `bash scripts/roadmap.sh validate` rejects a v2 task that still carries `status`.
- [x] 1.2 Implement status derivation from `openspec/changes/<change>/` and `openspec/changes/archive/*-<change>/` per design Decision 3, and use it in `next` and `list`. Verify with new `scripts/test-roadmap.sh` fixtures for pending, blocked, in_progress, done, and cancelled.
- [x] 1.3 Enforce the existing invariants on derived status (one `in_progress`, no claim before dependencies are done, no done task depending on unfinished work), with the bootstrap-change exemption from Decision 4. Verify with rejecting fixtures for each invariant and one for the exemption.
- [x] 1.4 Replace `set-status` with `claim <task-id> <change-name>`, guarded by `ROADMAP_ALLOW_WRITE=true` and dependency checks. Verify with tests that a claim without write mode, or with unfinished dependencies, is refused.
- [x] 1.5 Convert `roadmap/state.json` to v2: link the 16 historical tasks to `bootstrap-security-gate-specs`, link BASE-01 to `complete-ecosystem-baseline`, narrow PROF-02's objective and acceptance criteria to composition, and leave PROF-01 unlinked. Verify `bash scripts/roadmap.sh validate` passes and `bash scripts/roadmap.sh list` shows the expected derived statuses.
- [x] 1.6 Scaffold `complete-ecosystem-baseline` with `openspec new change "complete-ecosystem-baseline"` (scaffold only, no artifacts). Verify BASE-01 derives `in_progress`.
- [x] 1.7 Update `roadmap/README.md` for v2: derived status, `claim`, and how a task's change is created and archived. Verify every documented command runs as written and `bash scripts/check-docs.sh` passes.

## 2. Close spec proof gaps

- [x] 2.1 merge-gate: add `test-aggregate-results.sh` fixtures for `require-complete: false` with a skipped result (profile `pass`, skip still reported) and for zero received results (profile `fail`). Verify the suite passes and that each new fixture fails when its asserted behavior is mutated.
- [x] 2.2 consumable-output: prove the 20-finding default cap and full redaction of secret values with fixtures in the adapter or gitleaks suites. Verify the suite passes. If redaction cannot be proven without changing behavior, remove that scenario from the spec and record a follow-up task.
- [x] 2.3 ecosystem-baseline: prove that a Consumer Project's own Semgrep configuration is ignored with a fixture in `test-ecosystem-baseline.sh`. Verify the suite passes.
- [x] 2.4 evaluation-result: prove or remove the scenario "producers do not emit newer minor fields to an older consumer". Verify `openspec validate bootstrap-security-gate-specs --strict` still passes after any removal.
- [x] 2.5 release-integrity: prove or remove the rollback-by-one-SHA scenario using the release-graph check and a fixture pair. Verify the same way as 2.4.
- [x] 2.6 Walk every scenario in all nine specs against the design's proof map and record its proving check, test, or fixture in design.md. Verify that no scenario is left without proof.

## 3. Project context, docs, and CI

- [x] 3.1 Set `context` and a `specs` rule in `openspec/config.yaml` per design Decision 7. Verify `openspec instructions specs --change bootstrap-security-gate-specs --json` returns the new context and rule.
- [x] 3.2 Add the frozen-history banner to `docs/ECOSYSTEM-SECURITY-DECISION-MAP.md` and point maintainer docs (`docs/maintainers/README.md`, `docs/README.md`, `README.md`) to `openspec/` for behavior and in-flight work. Verify `bash scripts/check-docs.sh` passes.
- [x] 3.3 Teach `scripts/check-docs.sh` about `openspec/` (required paths and local links). Verify it fails when an `openspec/` doc link is broken.
- [x] 3.4 Add `openspec validate --all --strict` to `docs.yml`, with the CLI installed at an exact version and lifecycle scripts disabled. Update `security/workflow-policy.json` and `security/execution-trust.json`. Verify `check-workflow-security.sh`, `check-execution-trust.sh`, and actionlint pass.

## 4. Integration verification

- [x] 4.1 Run every suite in the design's proof map plus `test-roadmap.sh` and `check-docs.sh`. Verify all pass locally.
- [x] 4.2 Run `openspec validate --all --strict` and `bash scripts/roadmap.sh next`. Verify validation passes and `next` returns the expected next actionable task.

## Workflow follow-up

- Archive `bootstrap-security-gate-specs` after review, then confirm `openspec list --specs` shows nine capabilities.
- Remove the bootstrap-change exemption from `roadmap.sh` and its tests. Confirm the 16 historical tasks derive `done` and `test-roadmap.sh` passes.
