# License Compliance

**Workflow:** `sec-licenses.yml`<br>
**Status:** pre-v1 reusable evaluation<br>
**Introduced:** commit `f816e783c0230a4c0f9d74c8e925f04e5a4a7c7c`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** a project needs policy evidence for licenses visible in dependency manifests and lockfiles.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; dependencies are not installed |
| Network | GitHub actions and Trivy package/license metadata |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---|---|
| `severity` | `CRITICAL,HIGH` | License severities included in findings and gate |
| `blocking` | `false` | Fail on validated license findings |
| `skip-dirs` | Empty | Comma-separated excluded directories |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no `workflow_call` outputs. `evaluation-result-trivy-licenses` contains the normalized result and `trivy-license-results` contains SARIF. Findings appear in the summary and annotations. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

`blocking` controls policy finding failure. Tool failure or malformed evidence is an operational error. A complete zero-finding result applies only to the declared manifest/lockfile scope.

## Immutable Usage

```yaml
name: License compliance

on:
  pull_request:

jobs:
  licenses:
    permissions:
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-licenses.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Licenses visible only after dependency installation or build generation are excluded. Legal policy and exceptions remain a Consumer Project governance responsibility.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, evaluation IDs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-licenses.yml)
- [Consumable output contract](../reference/consumable-output.md)
- [Current contracts](../reference/current-contracts.md#individual-scanner-workflows)
