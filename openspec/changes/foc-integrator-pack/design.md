# Design

## Context

See proposal.md (Why). This section covers only the current state the approach depends on.

- `sec-semgrep.yml` runs one job in the digest-pinned `semgrep/semgrep:1.93.0` container. It invokes `actions/semgrep-scan`, which passes one `--config` (default `rules/ecosystem-baseline.yml`) and writes SARIF. It then calls `actions/evaluation-adapter` once, as `semgrep-baseline`. The checkout is shallow.
- The adapter blocks on **any** finding when `blocking: true`. It has no per-rule policy. It renders up to `MAX_SUMMARY_FINDINGS` rows, using rule help taken from `tool.driver.rules[].help`.
- `ecosystem-baseline.yml` composes five leaf workflows by immutable SHA. `Profile Conclusion` aggregates a fixed list of required evaluation ids. The release graph is layered: the umbrella SHA points to a leaf workflow SHA, which points to an action and assets SHA. Changing an action or rule therefore takes successive pin-advance commits (see `docs/reference/release-integrity.md` and commit `d1df527`).
- `actions/gitleaks-scan` passes `--config .gitleaks.toml` only when the Consumer Project has that file. Otherwise Gitleaks uses its built-in rules.
- The detector reads manifests as data and validates every profile it references against `profiles/filecoin-project-profiles.json`. It is not wired into the baseline workflow.
- `roadmap.sh validate` requires task `order` values to run `1..n` with no gaps, dependencies to point backward, and at most one task in progress. This branch is stacked on `archive-bootstrap-specs`, which removes the bootstrap exemption. As a result, the empty `complete-ecosystem-baseline` scaffold currently holds the in-progress slot through BASE-01.

## Goals / Non-Goals

**Goals:**
- Each FOC finding is actionable in place: one row saying what breaks on FOC, how to fix it, and a documentation link.
- No new consumer input. The pack arrives with the next baseline pin.
- The pack can never block a merge in this release, but a broken FOC scan cannot pass silently either.

**Non-Goals:**
- Per-rule gating inside one evaluation.
- Wiring detection output into the baseline summary or into evaluation selection. That is PROF-02.
- Promoting any rule to blocking.
- Restricting what Consumer Project Gitleaks configuration can do. Today that configuration replaces the default rules. This change only reports when the Filecoin rule is not applied.

## Decisions

### 1. Roadmap: insert FOC-01 at order 17 and drop the scaffold

FOC-01 is inserted at order 17, between EVAL-03 and BASE-01, and every later task's order is incremented by one. Its fields are:
- `phase: "ecosystem-baseline"`
- `priority: "P0"`
- `kind: "implementation"`
- `blocked_by: ["EVAL-03"]`
- `decision_refs: ["scanner-runtime", "evidence-interface"]`
- `change: "foc-integrator-pack"`
- Acceptance criteria and verification copied from the specs below.

FILE-01 adds FOC-01 to `blocked_by`, because FILE-01 inherits the rule format, the paired-fixture convention, and the precision record. BASE-01's `change` becomes `null`, and `openspec/changes/complete-ecosystem-baseline/` is deleted. That scaffold has no artifacts, so nothing is lost.

**Decision tickets.** Both referenced tickets are already resolved, and this design conforms to them:
- `scanner-runtime`: a thin tool invocation, followed by the generic adapter with caller-supplied identity, coverage, and policy.
- `evidence-interface`: one Evidence Bundle and one required check.

`profile-taxonomy` (open) is deliberately not referenced. Option A, FOC as an add-on, keeps the taxonomy unchanged.

**Alternative considered:** FOC-01 at the end of the list, with BASE-01 reordered behind it. Rejected because it renumbers the same tasks and misrepresents the priority.

### 2. A separate `semgrep-foc` evaluation in the existing static-analysis job

`sec-semgrep.yml` runs `semgrep-scan` twice in the same job and container: once with the baseline rules and once with `rules/foc-integrator.yml`, each writing its own SARIF. It then calls the adapter twice. The `semgrep-foc` call hard-codes `blocking: false` and does not read the `static-analysis-blocking` input. The umbrella workflow and `security-pipeline.yml` add `semgrep-foc` to the required evaluation list, so a missing or failed FOC result fails `Profile Conclusion` under `require-complete`.

**Alternatives considered:**
- **One evaluation, with per-rule advisory metadata read by the adapter.** Rejected. It adds policy logic to the shared adapter. FOC findings would also blend into the generic count, which defeats the purpose of making them visible.
- **A separate leaf workflow or job.** Rejected. It means another container pull, another pin chain, and more release-graph surface, all for the same trust tier.

### 3. New-versus-existing classification via SARIF `baselineState`

On `pull_request`, `sec-semgrep.yml` checks out with `fetch-depth: 0` and passes `github.event.pull_request.base.sha` to `semgrep-scan` as `baseline-ref`.

When `baseline-ref` is set, `semgrep-scan`:
- Runs the full scan, which is the evidence of record, as it does today.
- Runs a second pass with `--baseline-commit <ref>`, which returns only new findings.
- Uses `jq` to set `results[].baselineState` to `"new"` or `"unchanged"` in the full SARIF, matching on Semgrep's `fingerprints["matchBasedId/v1"]`.

Before either pass, git is hardened: `safe.directory` is set to the workspace, and `core.hooksPath=/dev/null` and `core.fsmonitor=false` are passed per invocation. No repository hook or monitor can then run during Semgrep's internal checkout of the base. If the second pass fails, `semgrep-scan` emits the unclassified full SARIF and the output `classification=unavailable`. The workflow then forwards a coverage limitation to the adapter (spec: Failed classification is visible, never fatal).

The adapter change is generic and keyed only on the standard SARIF field. When any result carries `baselineState`, the adapter:
- Prints `New: N, existing: M`.
- Sorts `new` before the rest, then applies the existing cap.
- Prints `...and K existing findings in raw evidence` for the remainder.

Without the field, the output is byte-identical to today's, and existing adapter fixtures prove that. Counts, gate, and the result schema do not change.

**Alternatives considered:**
- **Only `--baseline-commit`.** Rejected: the Evidence Bundle would lose existing findings.
- **Diff-hunk filtering in the adapter.** Rejected. A finding moved by an unrelated edit would show as new, and the adapter would need git access.
- **Changing gate semantics to count only new findings.** Rejected here. That is a policy change for every evaluation, and it belongs with the merge-gate work.

### 4. A repository-owned Gitleaks config that extends the defaults

`rules/gitleaks-filecoin.toml` uses `[extend] useDefault = true` and adds one rule, `filecoin-wallet-key-export`. The rule matches the hex encoding of `{"Type":"secp256k1"|"bls"|"delegated","PrivateKey":"`, that is, the prefix `7b2254797065223a22` followed by the key-type hex and the `PrivateKey` key hex, then a base64 payload of bounded length.

`gitleaks-scan` resolves its config in this order:
1. The Consumer Project's `.gitleaks.toml`, if present. This preserves the existing behavior and consumer allowlists, and the action outputs `filecoin-rules=not-applied`.
2. Otherwise, the control repository file, which outputs `filecoin-rules=applied`.

`sec-secrets.yml` forwards `not-applied` as a coverage limitation. The rule follows the existing `secrets-blocking` gate and is not forced to advisory. A committed key is a fact, not a heuristic, and the secrets gate is already consumer-selected.

**Alternative considered:** always using the control config, with the consumer config chained through `[extend] path`. Rejected for this change. It changes how existing consumer configs behave, which is a separate trust decision.

### 5. Detection add-ons come from the catalog

The catalog gains a top-level `add_ons` array: `[{id: "foc", label, description, signals}]`. The detector's catalog validation extends to `add_ons`, with unique ids and a fail-closed check on any unknown referenced id.

The `foc` signals are:
- A `@filoz/synapse-sdk` key in any `package.json` `dependencies` or `devDependencies`, read with `jq`.
- In `*.sol` files, an `import` line containing `PDPListener`, `IValidator`, `FilecoinPay`, or `Payments.sol`, matched with `grep -E` on files from `find`. Nothing is compiled or executed.

The result JSON gains `add_ons: [{id, evidence: [{path, reason}]}]`, and the action gains the `add-ons-json` output. The summary appends one line per detected add-on.

### 6. Rule design: anchor on FOC names and prefer misses over noise

Every rule carries `metadata`: `foc-impact`, `fix`, `references` (URLs), and `confidence`. Its `message` combines the impact and the fix, so the adapter's existing `help` column shows them without new rendering code. Any rule whose pattern cannot be expressed precisely on Semgrep 1.93.0 Solidity or TypeScript is narrowed until the clean fixture stays silent. Missed detections are acceptable in v1, and noise is not.

| Rule id | Anchor | Exempted by |
|---|---|---|
| `foc.solidity.callback-missing-caller-check` | functions named `dataSetCreated`, `dataSetDeleted`, `piecesAdded`, `piecesScheduledRemove`, `possessionProven`, `nextProvingPeriod`, `storageProviderChanged`, `validatePayment`, `railTerminated` | any `msg.sender` reference in the body, or any modifier |
| `foc.solidity.rail-terminated-can-revert` | `railTerminated` body | `require`/`revert`/external call only inside `try`/`catch` |
| `foc.solidity.transfer-send-reentrancy` | `$A.transfer($X)` / `$A.send($X)` with one argument | — |
| `foc.solidity.hardcoded-gas` | `{gas: <literal>}` call option, `gasleft()` compared with a literal | — |
| `foc.solidity.block-randomness` | `block.prevrandao`, `block.difficulty`, `blockhash(...)` | — |
| `foc.typescript.browser-exposed-private-key` | a `NEXT_PUBLIC_*`/`VITE_*`/`REACT_APP_*`/`PUBLIC_*` value from `process.env` or `import.meta.env` as `privateKey` to `Synapse.create`, or as the key to `new Wallet` / `privateKeyToAccount` | — |
| `foc.typescript.unlimited-operator-allowance` | `approveService`/`depositWithPermitAndApproveOperator`/`setOperatorApproval` with an explicit `maxUint256`, `MaxUint256`, `ethers.MaxUint256`, or `2n ** 256n - 1n` allowance | — |

**Spike results (task 2.1, Semgrep 1.93.0, SDK `synapse-sdk@c937823`, `pdp@3d486ae`, `filecoin-pay@04ded6a`):**
- The callback names match `PDPListener` in `PDPVerifier.sol` and `IValidator` in `FilecoinPayV1.sol`.
- `{ ... msg.sender ... }` and `{..., gas: $N}` do not parse in the Solidity grammar. The caller check uses a deep-expression statement, `<... msg.sender ...>;`. The exemption is written as `function $F(...) $M { ... }` and `$M(...)`, which exempts real modifiers but not `virtual` or `override`. The gas call option uses a regex. Interface and abstract declarations, which have no body, are not matched.
- In the current SDK, `Synapse.create` takes a viem `account`. The key sinks are therefore `privateKeyToAccount` and `new Wallet`. The older `privateKey:` option is kept.
- **Narrowed:** a bare `import.meta.env.*` read is how Astro and SvelteKit server code reads secrets, so the rule matches only the public prefixes.
- **Not flagged:** `approveService()` with allowances left out also defaults them to `maxUint256`. That is the SDK's standard flow, and flagging it would fire on every FOC app. The precision run (task 4.2) will show whether an advisory rule for an omitted allowance is worth adding later. Only an explicit unlimited value is flagged.
- `railTerminated` treats `abi.*`, `string.concat`, and `bytes.concat` as non-external calls, and its literal-only gas comparison is checked with `metavariable-regex`.

Exempting a callback that has *any* modifier is a deliberate precision trade-off, because it trusts `onlyVerifier`-style modifiers. The finding row for the caller-check rule says so.

The Synapse SDK method names (`Synapse.create`, `approveService`) are taken from the current SDK documentation. Task 2.1 verifies them against the `synapse-sdk` source before the rules are written.

### 7. Fixtures, the pack test, and the precision record

Fixtures live in `test/fixtures/foc-integrator/{positive,clean}/`, one file per rule in each directory. Positive lines carry `// ruleid: <id>` and clean files carry `// ok: <id>`, following the baseline convention.

`scripts/test-foc-integrator.sh` follows `test-ecosystem-baseline.sh`. It copies the rules and fixtures to `TMPDIR` to avoid Semgrep's default `test/` ignore, then checks:
- The scanned-file count equals the fixture-file count.
- Each rule fires in `positive/` and never in `clean/`.
- The pack produces zero findings on `test/fixtures/ecosystem-baseline/monorepo` (spec: Rules stay silent on non-FOC code).
- A planted consumer `.semgrep.yml` adds no rule.
- The baseline-state tagging: a scratch git repository with two commits yields one `new` and one `unchanged` result.
- Every rule id has an entry in `rules/foc-integrator-precision.json` with 40-hex commits.

G0 runs the script through the existing Docker `semgrep` wrapper.

`scripts/measure-foc-precision.sh` is maintainer-run only. CI never runs it, because it needs the network. It:
- Shallow-clones the four FilOzone repositories at pinned SHAs into a temporary directory.
- Scans them with the pinned image and the pack.
- Writes per-rule counts and finding locations into the record with `triage: "unreviewed"`.

The maintainer then sets each finding to `true-positive` or `false-positive` with a short note. The pack test fails on any remaining `unreviewed` entry.

### 8. Proving checks per scenario

| Spec scenario | Proof |
|---|---|
| foc-integrator-pack: all rule, fixture, silence, config, and precision scenarios | `scripts/test-foc-integrator.sh` |
| foc-integrator-pack: advisory under `static-analysis-blocking: true` | `scripts/check-scanner-gates.sh`, which asserts `semgrep-foc` is wired with literal `blocking: false`; and `scripts/test-ecosystem-baseline.sh`, which greps for it |
| foc-integrator-pack: FOC scan fails, so profile fails; ecosystem-baseline: FOC result missing | `scripts/test-aggregate-results.sh`, with a fixture missing `semgrep-foc`, plus the required-list check in `test-ecosystem-baseline.sh` |
| foc-integrator-pack: wallet key and consumer-config limitation | `scripts/test-gitleaks-scan.sh`, which plants a hex export and checks for redaction; a second case with a consumer `.gitleaks.toml` asserts `filecoin-rules=not-applied` |
| ecosystem-baseline: six evaluations; findings reported separately | `scripts/test-ecosystem-baseline.sh` (expected-evaluation list) and `scripts/check-output-contract.sh` (inventory) |
| consumable-output: new findings lead; no classification; classification unavailable | `scripts/test-evaluation-adapter.sh`, with SARIF fixtures that have and lack `baselineState`; the byte-identical case reuses the existing expected output. Plus `test-foc-integrator.sh` for the unavailable path |
| profile-detection: add-on scenarios and empty `add-ons-json` | `scripts/test-detect-filecoin-profile.sh`, with new fixtures under `test/fixtures/profile-detection/` |

## Risks / Trade-offs

- [Semgrep 1.93.0 Solidity support may not express "function body never references `msg.sender`" cleanly] → Task 2.1 spikes each pattern first. Any rule that cannot stay silent on its clean fixture is narrowed or dropped from v1, and the drop is recorded in the precision record. The spec's rule list then needs a matching edit before archive.
- [`--baseline-commit` makes Semgrep run git on untrusted repository content] → Hooks and fsmonitor are disabled per invocation, nothing is installed or built, and the trust tier is unchanged. `check-baseline-no-exec.sh` gains an assertion that the hardening flags are present.
- [The second Semgrep pass roughly doubles static-analysis time on pull requests] → It applies only to pull requests and the rule sets are small. If the time is too long, BASE-02 (fast and deep lanes) is where to move it.
- [Pinned SHAs must stay reachable after merge] → The layered pins point at commits on this branch. The PR must be merged with a merge commit, not squashed, as previous PRs were. The PR body says so.
- [A consumer can silence pack findings with `nosemgrep` without that being reported] → This is accepted while the pack is advisory. BASE-01, which is next on the roadmap, reports exclusions.
- [Consumer `.gitleaks.toml` disables the Filecoin key rule] → This is reported as a coverage limitation, not hidden.

## Migration Plan

1. Merge `archive-bootstrap-specs` first. This branch is stacked on it, and its PR diff shrinks to this change once that PR merges.
2. Implement in layered commits:
   1. Assets: rules, actions, catalog, scripts.
   2. Leaf workflows pinned to the assets commit.
   3. Umbrella and privileged pipeline pinned to the leaf commit.
   4. The `check-release-graph.sh` and G0 run.
3. Consumers adopt by advancing their one baseline SHA. Nothing else changes. Rollback is pinning the previous SHA.

## Open Questions

- The exact pinned FilOzone commits for the first precision record are chosen when task 4.2 runs, from those repositories' default branches at that time.
