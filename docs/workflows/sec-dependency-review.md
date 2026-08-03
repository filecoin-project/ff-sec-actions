# Dependency Review

**Workflow:** `sec-dependency-review.yml`  
**Status:** pre-v1 provider-native evaluation  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a pull request should be checked for newly introduced vulnerable or disallowed dependencies.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read`, `pull-requests: write` |
| Secrets | None |
| Consumer code execution | None |
| Network | GitHub dependency graph, advisory data, and PR API |
| Events and forks | Pull requests only; fork PR comment publication depends on caller token restrictions |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `fail-on-severity` | `high` | Minimum advisory severity that fails the check |
| `deny-licenses` | `GPL-3.0, AGPL-3.0` | Comma-separated prohibited licenses |

## Outputs And Evidence

There are no `workflow_call` outputs or standalone artifact. The provider-native surface is the Dependency Review job summary, source annotations, and an always-published PR comment. Retention follows the Consumer Project's pull-request and Actions log retention settings.

## Completion And Gating

The GitHub Dependency Review action gates at `fail-on-severity` and the denied-license policy. Missing dependency-graph support or action failure fails the job rather than producing normalized Evaluation Result evidence.

## Immutable Usage

```yaml
jobs:
  dependency-review:
    permissions:
      contents: read
      pull-requests: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-dependency-review.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

This workflow is meaningful only for pull requests and depends on GitHub's dependency graph. Comment publication is currently coupled to evaluation authority.

## Compatibility

This is a pre-v1 provider-native contract with no deprecated inputs. Changing policy inputs, pull-request publication, or failure behavior requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-dependency-review.yml)
- [Execution trust](../reference/execution-trust.md)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
