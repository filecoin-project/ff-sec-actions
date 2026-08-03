# Dependency Scan

**Workflow:** `sec-dependencies.yml`  
**Status:** pre-v1 reusable evaluation  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a project needs secretless vulnerability analysis of source-visible dependency manifests and lockfiles.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `actions: read`, `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; package managers and builds are not invoked |
| Network | GitHub actions, package metadata, and Trivy vulnerability data |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `severity` | `CRITICAL,HIGH,MEDIUM` | Severities included in findings and gates |
| `blocking` | `false` | Fail on validated findings |
| `skip-dirs` | `node_modules` | Comma-separated excluded directories |
| `trivyignore-file` | `.trivyignore` | Exception file used only when present |

## Outputs And Evidence

There are no `workflow_call` outputs. `evaluation-result-trivy-dependencies` contains the normalized result; `trivy-deps-results` contains SARIF. The job summary and annotations show actionable findings. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

Trivy findings are normalized even though the scanner step uses `continue-on-error`. `blocking` controls finding failure; scanner failure, timeout, or malformed evidence remains an operational error.

## Immutable Usage

```yaml
jobs:
  dependencies:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-dependencies.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Coverage excludes installed state and build-generated manifests. Reachability and packages visible only after installation require a separately isolated build analysis.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, evaluation IDs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-dependencies.yml)
- [Consumable output contract](../reference/consumable-output.md)
- [Current contracts](../reference/current-contracts.md#individual-scanner-workflows)
