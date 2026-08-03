# AI Code Review

**Workflow:** `ai-code-review.yml`<br>
**Status:** pre-v1<br>
**Introduced:** commit `ae7c3f8abd607f11648a13469a5f28eda6ef5f59`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
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

**Declared secrets:** `anthropic-api-key` (optional)

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

**Declared workflow outputs:** `findings-count`, `highest-severity`, `completion-status`, `evaluation-result`, `evidence-artifact-url`

| Output | Consumer meaning |
|---|---|
| `findings-count` | Number of structured findings; use for reporting, not completion |
| `highest-severity` | Highest reported finding severity, or `none` |
| `completion-status` | `complete`, `incomplete`, `skipped`, or `error`; check this before findings |
| `evaluation-result` | Callee-local result path; it is not readable from a later caller job |
| `evidence-artifact-url` | Durable artifact URL; use this to retrieve the Evaluation Result and findings |

The durable artifact is `evaluation-result-ai-code-review`; the PR comment and job summary provide the readable surface. The artifact uses the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

Missing credentials produce `skipped`; refusal or truncation can produce `incomplete`; provider or parsing failures produce `error`. `fail-on-severity` controls the finding gate independently. A green job is meaningful only when `completion-status` is `complete`.

## Immutable Usage

```yaml
name: AI security review

on:
  pull_request:

jobs:
  ai-review:
    permissions:
      contents: read
      pull-requests: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/ai-code-review.yml@c95d54087ff3a4783aea814776243990d9778c93
    secrets:
      anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}

  require-complete-review:
    needs: ai-review
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Require a completed provider review
        env:
          COMPLETION_STATUS: ${{ needs.ai-review.outputs.completion-status }}
          EVIDENCE_URL: ${{ needs.ai-review.outputs.evidence-artifact-url }}
        run: |
          echo "Evidence: ${EVIDENCE_URL}"
          test "${COMPLETION_STATUS}" = complete
```

## Limitations

Diff-only context can miss repository-wide behavior. Fork PRs normally cannot access the provider secret. Review privacy, retention, cost, and comment authority before adoption.

## Compatibility

This is a pre-v1 contract with no deprecated inputs. Renaming inputs, outputs, completion states, or evidence artifacts requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/ai-code-review.yml)
- [Current contract details](../reference/current-contracts.md#ai-reusable-workflow)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
