# Evaluation Pipeline

**Workflow:** `evaluation-pipeline.yml`<br>
**Status:** pre-v1 vertical slice<br>
**Introduced:** commit `c0b61023e4c24d417503450cbc6d174c69bb47df`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** a reviewer needs the smallest working example of normalized evaluation, artifact handoff, aggregation, and Profile Conclusion.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | Caller cap: `actions: read`, `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; dependency manifests and lockfiles are inspected |
| Network | GitHub actions/artifacts and Trivy vulnerability data |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---:|---|
| `dependency-blocking` | `false` | Gate dependency findings |
| `require-complete` | `true` | Require the dependency evaluation to complete |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no `workflow_call` outputs. The dependency job publishes normalized and raw Trivy evidence. The aggregator publishes the `evidence-bundle` artifact with `evidence-bundle.json` and `evidence-summary.md`. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

The Profile Conclusion requires `trivy-dependencies`. Findings fail only when `dependency-blocking=true`; missing or incomplete evaluation fails when `require-complete=true`.

## Immutable Usage

```yaml
name: Dependency evaluation contract

on:
  pull_request:

jobs:
  evaluation:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/evaluation-pipeline.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

This is a contract demonstration, not a broad security profile. It evaluates dependency evidence only.

## Compatibility

This is a pre-v1 demonstration contract with no deprecated inputs. Changing its evaluation ID, evidence filenames, inputs, or conclusion semantics requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/evaluation-pipeline.yml)
- [Evaluation Result](../reference/evaluation-result.md)
- [Evidence Bundle](../reference/evidence-bundle.md)
