# OpenSSF Scorecard

**Workflow:** `sec-scorecard.yml`  
**Status:** pre-v1 provider-native evaluation  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a public repository needs OpenSSF supply-chain posture checks and accepts the publication authority.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read`, `security-events: write`, `id-token: write` |
| Secrets | None; OIDC authenticates supported publication |
| Consumer code execution | None |
| External transfer | Optional OpenSSF REST publication plus GitHub Code Scanning |
| Events and forks | Prefer push, schedule, or manual dispatch; the umbrella skips pull requests and fork PR publication is not supported |

## Inputs

| Input | Default | Purpose |
|---|---:|---|
| `publish-results` | `true` | Publish results to OpenSSF for public repositories |

## Outputs And Evidence

There are no `workflow_call` outputs. `scorecard-results` contains SARIF. When `ENABLE_GHAS='true'`, results are also uploaded to GitHub Code Scanning. Artifact retention follows the Consumer Project's Actions setting; uploaded alerts follow its GitHub Code Security settings.

## Completion And Gating

Scorecard findings are advisory in this workflow. Action or evidence-generation failure fails the job. Security-tab publication is conditional on the Consumer Project variable and product availability.

## Immutable Usage

```yaml
jobs:
  scorecard:
    permissions:
      contents: read
      security-events: write
      id-token: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-scorecard.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

The current workflow combines read-only evaluation with OIDC and Security-tab publication and is classified `legacy-mixed`. Private repositories should normally disable public result publication.

## Compatibility

This is a pre-v1 provider-native contract with no deprecated inputs. Changing OIDC/publication behavior, evidence naming, or inputs requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-scorecard.yml)
- [Execution trust](../reference/execution-trust.md)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
