# Semgrep SAST

**Workflow:** `sec-semgrep.yml`<br>
**Status:** pre-v1 reusable evaluation<br>
**Introduced:** commit `f816e783c0230a4c0f9d74c8e925f04e5a4a7c7c`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** supported source languages need repository-owned Ecosystem Baseline pattern checks, and Filecoin Onchain Cloud integrations need the FOC integrator pack, without project execution.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `actions: read`, `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; source is parsed inside a digest-pinned scanner image |
| Network | GitHub actions and pinned container retrieval; Semgrep metrics/version checks are disabled |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---:|---|
| `blocking` | `false` | Fail on validated Ecosystem Baseline findings; FOC integrator pack findings stay advisory |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no `workflow_call` outputs. The job emits two Evaluation Results: `semgrep-baseline` (`evaluation-result-semgrep-baseline`, SARIF in `semgrep-baseline-results`) and `semgrep-foc` (`evaluation-result-semgrep-foc`, SARIF in `semgrep-foc-results`) from the [FOC integrator pack](../reference/foc-integrator-pack.md). The summaries and annotations include source locations and remediation guidance. On pull requests the checkout includes history so each finding is marked new or existing relative to the base commit; summaries lead with new findings. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

Each scanner step preserves its exit status for normalization. `blocking` controls `semgrep-baseline` finding failure; `semgrep-foc` is wired with `blocking: false`. For either evaluation, missing output, invalid SARIF, timeout, or scanner failure produces an operational error. If new-versus-existing classification is unavailable, the evaluation still completes and records a coverage limitation.

## Immutable Usage

```yaml
name: Semgrep ecosystem checks

on:
  pull_request:

jobs:
  semgrep:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-semgrep.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Coverage is limited to maintained rules for supported Go, Rust, JavaScript, TypeScript, Solidity, and Dockerfile source, plus the FOC integrator pack's Solidity and JavaScript/TypeScript rules. Generated and unsupported-language source is excluded.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Changing maintained rules, evaluation IDs, inputs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-semgrep.yml)
- [Baseline rules](../reference/ecosystem-baseline-rules.md)
- [Consumable output contract](../reference/consumable-output.md)
