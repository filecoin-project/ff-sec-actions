# AI Code Review

**Workflow:** `ai-code-review.yml`  
**Status:** pre-v1  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a pull request needs Filecoin-aware, diff-focused review with structured findings and optional sticky commenting.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read`, `pull-requests: write` |
| Secrets | Optional `anthropic-api-key`; missing secret produces a skipped result |
| External transfer | PR metadata and bounded diff are sent to Anthropic |
| Consumer code execution | None; the workflow does not checkout or execute the PR |
| Events | Primarily pull requests; caller supplies the event context |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `model` | `claude-opus-4-8` | Anthropic model identifier |
| `domain` | `filecoin` | Domain prompt selection |
| `effort` | `high` | Review effort level |
| `max-tokens` | `16000` | Response token ceiling |
| `max-diff-bytes` | `400000` | Diff byte ceiling before truncation |
| `exclude-pattern` | Empty | Extended regex for excluded paths |
| `fail-on-severity` | `none` | Finding severity converted into a failing gate |
| `post-comment` | `true` | Publish/update the PR comment |

Secret: `anthropic-api-key` is optional at dispatch but required for a complete provider review.

## Outputs And Evidence

Workflow outputs are `findings-count`, `highest-severity`, `completion-status`, `evaluation-result`, and `evidence-artifact-url`. The durable artifact is `evaluation-result-ai-code-review`; the PR comment and job summary provide the readable surface. The workflow's `artifact-retention-days` input controls artifact retention.

## Completion And Gating

Missing credentials produce `skipped`; refusal or truncation can produce `incomplete`; provider or parsing failures produce `error`. `fail-on-severity` controls the finding gate independently. A green job is meaningful only when `completion-status` is `complete`.

## Immutable Usage

```yaml
jobs:
  ai-review:
    permissions:
      contents: read
      pull-requests: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/ai-code-review.yml@c95d54087ff3a4783aea814776243990d9778c93
    secrets:
      anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

## Limitations

Diff-only context can miss repository-wide behavior. Fork PRs normally cannot access the provider secret. Review privacy, retention, cost, and comment authority before adoption.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, outputs, completion states, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/ai-code-review.yml)
- [Current contract details](../reference/current-contracts.md#ai-reusable-workflow)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
