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

The AI examples use the composite action at a reviewed pilot commit. The
reusable AI workflow resolves that action immutably. The scanner example uses
a reviewed umbrella commit that selects the complete immutable graph.

## AI Code Review Composite Action

Source: [`actions/ai-code-review/action.yml`](../../actions/ai-code-review/action.yml)

| Input | Required | Default | Purpose |
|---|---:|---|---|
| `anthropic-api-key` | No | Empty | Authenticate the request; empty emits `skipped` |
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
| `completion-status` | `complete`, `incomplete`, `skipped`, or `error` |
| `evaluation-result` | Runner-local path to the v1 Evaluation Result JSON |

Current limitations:

- refusal and truncation are explicit `incomplete` results, but large diffs are
  not yet partitioned;
- a normal fork PR cannot access the Anthropic secret and emits `skipped`;
- diff-only context can miss repository-wide behavior.

## AI Reusable Workflow

Source: [`.github/workflows/ai-code-review.yml`](../../.github/workflows/ai-code-review.yml)

The reusable workflow currently exposes:

- inputs: `model`, `domain`, `effort`, `max-tokens`, `max-diff-bytes`,
  `exclude-pattern`, `fail-on-severity`, and `post-comment`;
- optional secret: `anthropic-api-key` (missing emits `skipped`);
- outputs: `findings-count`, `highest-severity`, `completion-status`, and
  `evaluation-result`.

It does not mirror the composite action's `github-token`, `pr-number`, `repo`,
`prompt-file`, or `findings-json` surface. Its internal action reference is
pinned to a full repository commit.

## Security Pipeline Umbrella

Source:
[`.github/workflows/security-pipeline.yml`](../../.github/workflows/security-pipeline.yml)

The separate [evaluation vertical slice](../../.github/workflows/evaluation-pipeline.yml)
proves normalized artifact handoff, one Evidence Bundle, a readable summary,
and the stable `Profile Conclusion` check for dependency evaluation. The legacy
umbrella has not yet migrated all scanners to that aggregate contract.

The [Ecosystem Baseline](../../.github/workflows/ecosystem-baseline.yml) is the
consumer-testable normalized profile. It composes workflow security,
dependencies, secrets, IaC, and repository-owned static rules, then emits one
Evidence Bundle and `Profile Conclusion`. Its inputs are
`actions-security-blocking`, `dependency-blocking`, `iac-blocking`,
`static-analysis-blocking`, `require-complete`, and `skip-dirs`.

### Scanner Toggles

| Input | Default | Event behavior |
|---|---:|---|
| `enable-semgrep` | `true` | Runs when enabled |
| `enable-actions-security` | `true` | Offline GitHub Actions syntax/security analysis |
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
| `skip-dirs` | `node_modules` | Comma-separated Trivy exclusions |
| `actions-security-blocking` | `false` | Fail on workflow-definition findings; tool failure always fails |
| `semgrep-blocking` | `false` | Fail on custom-rule findings; tool failure always fails |
| `codeql-languages` | `["javascript-typescript"]` | JSON array |
| `dependency-review-fail-on-severity` | `high` | Dependency-review threshold |
| `dependency-blocking` | `false` | Fail on dependency findings; tool failure always fails |
| `dependency-severity` | `CRITICAL,HIGH,MEDIUM` | Dependency findings included in the gate |
| `publish-sarif` | `false` | Privileged umbrella only: publish dependency SARIF in a separate write-authorized job |
| `iac-blocking` | `false` | Fail on IaC findings; tool failure always fails |
| `iac-severity` | `CRITICAL,HIGH,MEDIUM` | IaC findings included in the gate |
| `license-blocking` | `false` | Fail on license findings; tool failure always fails |
| `license-severity` | `CRITICAL,HIGH` | License findings included in the gate |
| `deny-licenses` | `GPL-3.0, AGPL-3.0` | Dependency-review deny list |
| `slither-target` | `.` | Solidity target |
| `slither-args` | Empty | Additional Slither arguments |
| `solc-version` | `0.8.13` | Solidity compiler version |
| `slither-fail-on` | `none` | `none`, `low`, `medium`, `high`, `all`, or `config` |

The default scanner suite requires no repository or organization secret.
Gitleaks uses the checksum-pinned open-source CLI: pull requests inspect the PR
commit range, while push, schedule, and manual events inspect full history.

The dependency Trivy slice uses the generic v1 Evaluation Adapter; remaining
Trivy slices retain the compatibility outcome adapter while they migrate. Both
independently validate results and operational status. See
the [Trivy Action inputs](https://github.com/aquasecurity/trivy-action#inputs).
Slither forwards its documented `fail-on` threshold; see the
[Slither Action fail behavior](https://github.com/crytic/slither-action#action-fail-behavior).

Current full-suite umbrella limitations:

- the legacy full-suite parent does not aggregate one Evidence Bundle; use the
  Ecosystem Baseline when one authoritative `Profile Conclusion` is required;
- dependency, license, and SBOM evidence is manifest/lockfile based and can be
  incomplete when packages appear only after installation or a build;
- callers must currently grant the cap required by all enabled nested jobs.

## Individual Scanner Workflows

| Workflow | Primary result | Current gate behavior |
|---|---|---|
| `sec-actions.yml` | Checksum-pinned offline Zizmor SARIF with exact locations and remediation links | Configurable finding gate; malformed output/tool failure always fails |
| `sec-semgrep.yml` | Repository-owned custom-rule SARIF artifact | Configurable finding gate; malformed output/tool failure always fails |
| `sec-codeql.yml` | GitHub code-scanning analysis | CodeQL analysis controls failure |
| `sec-dependencies.yml` | Manifest/lockfile Trivy SARIF plus v1 Evaluation Result | Generic adapter; configurable finding gate; timeout, malformed output, and tool failure remain distinct |
| `sec-secrets.yml` | Secretless Gitleaks SARIF; PR range or full history | Blocking; findings and operational failure remain distinct |
| `sec-iac.yml` | Trivy SARIF | Configurable finding gate; malformed output/tool failure always fails |
| `sec-licenses.yml` | Trivy SARIF artifact | Configurable finding gate; malformed output/tool failure always fails |
| `sec-dependency-review.yml` | PR summary | Blocks at configured severity/license policy |
| `sec-sbom.yml` | CycloneDX artifact | Informational |
| `sec-scorecard.yml` | Scorecard SARIF/artifact | Findings advisory; operational failure fails |
| `sec-slither.yml` | Slither SARIF/artifact | Configurable finding gate; operational failure fails |

Source links for each workflow are available in the [reference
index](README.md).

## Variables And Permissions

The Ecosystem Baseline never reads `ENABLE_GHAS` and never requests
`security-events: write`. The privileged full-suite example converts
`ENABLE_GHAS='true'` into the explicit `publish-sarif` input; private repository
product availability still applies. Dependency SARIF publication runs in a
separate privileged-umbrella job, outside the reusable inspection workflow, so
the inspection permission envelope remains read-only.

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
