# Secretless Gitleaks Scan

**Workflow:** `sec-secrets.yml`  
**Status:** pre-v1 reusable evaluation  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a project needs fully redacted secret detection over a pull-request commit range or complete Git history.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read` |
| Secrets and writes | None; detected values are redacted before presentation |
| Consumer code execution | None; Git objects are inspected as data |
| Network | GitHub actions and checksum-verified Gitleaks release download |
| Events and forks | Caller-controlled contexts; fork PRs use the introduced commit range without secrets or write authority |
| Checkout | Full history with credentials not persisted |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `config-path` | `.gitleaks.toml` | Repository configuration used only when present |
| `scan-scope` | `auto` | `auto`, `pr-diff`, or `full-history` |
| `blocking` | `true` | Fail on validated secret findings |

## Outputs And Evidence

There are no `workflow_call` outputs. `evaluation-result-gitleaks` contains the redacted normalized result. `gitleaks-results` contains redacted SARIF and is retained for 14 days. The summary and annotations never include secret values.

## Completion And Gating

Findings are a successful scanner invocation and fail only when `blocking=true`. Operational failure and malformed evidence remain errors. On pull requests, `auto` selects the introduced commit range; other events select full history.

## Immutable Usage

```yaml
jobs:
  secrets:
    permissions:
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-secrets.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

PR-range scanning does not re-audit older history. Rotate or revoke a real credential before source/history cleanup, and suppress only a verified false positive.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming scan scopes, inputs, evaluation IDs, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-secrets.yml)
- [Understand results](../consumers/understand-results.md)
- [Consumable output contract](../reference/consumable-output.md)
