# Trivy IaC Scan

**Workflow:** `sec-iac.yml`  
**Status:** pre-v1 reusable evaluation  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** Terraform, Kubernetes, container, or other supported infrastructure configuration needs static misconfiguration analysis.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `actions: read`, `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; configuration is inspected as data |
| Network | GitHub actions and Trivy policy/vulnerability data |
| Events and forks | Caller-controlled contexts; fork PRs are supported without secrets or write authority |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `severity` | `CRITICAL,HIGH,MEDIUM` | Severities included in findings and gate |
| `skip-dirs` | `node_modules` | Comma-separated excluded directories |
| `blocking` | `false` | Fail on validated findings |

## Outputs And Evidence

There are no `workflow_call` outputs. `evaluation-result-trivy-iac` contains the normalized result; `trivy-iac-results` contains SARIF. The job summary and annotations provide remediation context. Artifacts use the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

`blocking` controls finding failure. Trivy invocation failure, timeout, or malformed SARIF is normalized separately and cannot pass as zero findings.

## Immutable Usage

```yaml
jobs:
  iac:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-iac.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Coverage includes configuration recognized by Trivy, not runtime cloud state, effective IAM, deployed drift, or organization policy outside the repository.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, evaluation IDs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-iac.yml)
- [Consumable output contract](../reference/consumable-output.md)
- [Current contracts](../reference/current-contracts.md#individual-scanner-workflows)
