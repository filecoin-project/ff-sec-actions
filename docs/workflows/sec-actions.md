# GitHub Actions Security

**Workflow:** `sec-actions.yml`<br>
**Status:** pre-v1 reusable evaluation<br>
**Introduced:** commit `18f2285f8b0d3129350ae02a15ff8160032875d9`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** a project needs static security analysis of workflow and action definitions without GitHub Code Security authority.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; Zizmor runs offline against definitions as data |
| Network | Pinned action download and checksum-verified Zizmor release download |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---|---|
| `config-path` | Empty | Explicit Zizmor configuration; empty disables discovery |
| `blocking` | `false` | Fail when validated findings exist |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no `workflow_call` outputs. `evaluation-result-zizmor-actions` contains the normalized result and `zizmor-actions-results` contains SARIF. Findings also appear in the job summary and source annotations. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

Findings are operational success and gate only when `blocking=true`. Missing tool, invalid SARIF, or other operational errors remain distinct and fail evaluation normalization.

## Immutable Usage

```yaml
name: GitHub Actions security

on:
  pull_request:

jobs:
  actions-security:
    permissions:
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-actions.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Offline mode does not resolve remote action metadata or perform online repository audits. Repository configuration is ignored unless explicitly selected.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, evaluation IDs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-actions.yml)
- [Zizmor adapter](../reference/zizmor-scan.md)
- [Fork safety](../reference/fork-pr-safety.md)
