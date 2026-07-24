# Current Pre-v1 Contracts

**For:** a Consumer Engineer who needs current inputs, outputs, defaults, and
behavior without reading workflow YAML.

**Outcome:** configure the existing pilot surfaces while recognizing where
their contracts differ from the target v1 platform.

> This reference describes the current pre-v1 repository state and is manually
> maintained. It is not a stable release contract. Generated reference and
> metadata-agreement tests are required before public v1.

## Consumption Surfaces

| Surface | Use when | Consumer owns |
|---|---|---|
| Reusable workflow | You want a complete pre-wired job | Trigger, caller permission cap, inputs, and secrets |
| Composite action | You need a step inside a custom job | Runner, permissions, setup, and surrounding steps |
| Standalone script | You are developing locally or outside GitHub Actions | Runtime tools, environment, credentials, and output paths |

The AI examples currently use the composite action because the reusable AI
workflow contains an unresolved release reference. The scanner example uses
the umbrella on `main` and is explicitly pilot-only.

## AI Code Review Composite Action

Source: [`actions/ai-code-review/action.yml`](../../actions/ai-code-review/action.yml)

| Input | Required | Default | Purpose |
|---|---:|---|---|
| `anthropic-api-key` | Yes | — | Authenticate the Anthropic request |
| `github-token` | No | `github.token` | Read PR metadata/diff and optionally write a comment |
| `pr-number` | No | Current PR | Select a PR for dispatch or cross-repository use |
| `repo` | No | Current repository | Select the repository containing the PR |
| `model` | No | `claude-opus-4-8` | Anthropic model identifier |
| `domain` | No | `filecoin` | Resolve `prompts/<domain>.md` |
| `prompt-file` | No | Empty | Override the domain prompt with an absolute path |
| `effort` | No | `high` | `low`, `medium`, `high`, or `max` |
| `max-tokens` | No | `16000` | Response token limit |
| `max-diff-bytes` | No | `400000` | Raw byte limit before diff truncation |
| `exclude-pattern` | No | Built-in filter | Extended regular expression for excluded paths |
| `fail-on-severity` | No | `none` | `none`, `critical`, `high`, `medium`, or `low` |
| `post-comment` | No | `true` | Post or update the sticky PR comment |

Outputs:

| Output | Meaning |
|---|---|
| `findings-count` | Number of structured findings |
| `highest-severity` | Highest finding severity or `none` |
| `findings-json` | Runner-local path to the structured result |

Current limitations:

- refusal exits successfully with zero findings;
- large diffs are truncated rather than partitioned;
- there is no separate Completion Status;
- a normal fork PR cannot access the Anthropic secret;
- diff-only context can miss repository-wide behavior.

## AI Reusable Workflow

Source: [`.github/workflows/ai-code-review.yml`](../../.github/workflows/ai-code-review.yml)

The reusable workflow currently exposes:

- inputs: `model`, `domain`, `effort`, `max-tokens`, `max-diff-bytes`,
  `exclude-pattern`, `fail-on-severity`, and `post-comment`;
- required secret: `anthropic-api-key`;
- outputs: `findings-count` and `highest-severity`.

It does not mirror the composite action's `github-token`, `pr-number`, `repo`,
`prompt-file`, or `findings-json` surface. Its internal action reference points
to an unreleased `v1`, so the consumer examples do not use it.

## Security Pipeline Umbrella

Source:
[`.github/workflows/security-pipeline.yml`](../../.github/workflows/security-pipeline.yml)

### Scanner Toggles

| Input | Default | Event behavior |
|---|---:|---|
| `enable-semgrep` | `true` | Runs when enabled |
| `enable-codeql` | `false` | Runs when enabled; product availability applies |
| `enable-dependencies` | `true` | Runs when enabled |
| `enable-secrets` | `true` | Runs when enabled |
| `enable-iac` | `true` | Runs when enabled |
| `enable-licenses` | `true` | Runs when enabled |
| `enable-dependency-review` | `true` | Pull requests only |
| `enable-sbom` | `true` | Excluded from pull requests |
| `enable-scorecard` | `false` | Excluded from pull requests |
| `enable-slither` | `false` | Runs when enabled |

### Shared Inputs

| Input | Default | Notes |
|---|---|---|
| `package-manager` | `none` | `pnpm`, `npm`, or `none` |
| `node-version` | `24` | Used by npm/pnpm paths |
| `skip-dirs` | `node_modules` | Comma-separated Trivy exclusions |
| `semgrep-community-configs` | TypeScript/JWT/OWASP/secrets/security-audit sets | Space-separated registry configs |
| `codeql-languages` | `["javascript-typescript"]` | JSON array |
| `dependency-review-fail-on-severity` | `high` | Dependency-review threshold |
| `deny-licenses` | `GPL-3.0, AGPL-3.0` | Dependency-review deny list |
| `slither-target` | `.` | Solidity target |
| `slither-args` | Empty | Additional Slither arguments |
| `solc-version` | `0.8.13` | Solidity compiler version |

Optional secret: `gitleaks-license`.

Current umbrella limitations:

- nested workflows load from mutable `main`;
- Semgrep, dependency, IaC, license, and Slither blocking controls are not all
  exposed or forwarded;
- the parent workflow does not aggregate one Evaluation Result;
- npm/pnpm paths in dependency, license, and SBOM workflows install
  dependencies and may execute lifecycle scripts;
- callers must currently grant the cap required by all enabled nested jobs.

## Individual Scanner Workflows

| Workflow | Primary result | Current gate behavior |
|---|---|---|
| `sec-semgrep.yml` | Custom and community SARIF artifacts | Custom rules can block à la carte; community rules are advisory |
| `sec-codeql.yml` | GitHub code-scanning analysis | CodeQL analysis controls failure |
| `sec-dependencies.yml` | Native audit plus Trivy SARIF | Native audit can block à la carte; Trivy is advisory |
| `sec-secrets.yml` | Gitleaks summary/artifact | Blocking |
| `sec-iac.yml` | Trivy SARIF | `blocking` exists, but Trivy finding exit semantics need G0 correction |
| `sec-licenses.yml` | Trivy table in logs | Advisory; no artifact is currently uploaded |
| `sec-dependency-review.yml` | PR summary | Blocks at configured severity/license policy |
| `sec-sbom.yml` | CycloneDX artifact | Informational |
| `sec-scorecard.yml` | Scorecard SARIF/artifact | Advisory |
| `sec-slither.yml` | Slither SARIF/artifact | Can block à la carte |

Source links for each workflow are available in the [reference
index](README.md).

## Variables And Permissions

`ENABLE_GHAS='true'` currently enables conditional SARIF upload steps. Private
repository product availability still applies.

Possible permissions across the current workflows:

| Permission | Used for |
|---|---|
| `contents: read` | Checkout and repository inspection |
| `actions: read` | Some scanner/action behavior |
| `security-events: write` | SARIF upload |
| `pull-requests: write` | AI and dependency-review comments |
| `id-token: write` | Scorecard publishing |

Grant only the permissions needed by enabled jobs. See
[Permissions and secrets](../consumers/permissions-and-secrets.md).

## Trigger Behavior

| Trigger | Current use |
|---|---|
| `pull_request` | Diff review, scanners, and dependency review; fork secrets unavailable |
| `push` | Main/release auditing and non-PR artifacts |
| `schedule` | Recurring full scans and SBOM refresh |
| `workflow_dispatch` | On-demand evaluation |

## Next

- [Start with the quickstart](../consumers/quickstart.md)
- [Understand results](../consumers/understand-results.md)
- [Review permissions](../consumers/permissions-and-secrets.md)
