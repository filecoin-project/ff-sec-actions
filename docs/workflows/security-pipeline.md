# Security Pipeline

**Workflow:** `security-pipeline.yml`<br>
**Status:** pre-v1 legacy mixed-authority umbrella<br>
**Introduced:** commit `f816e783c0230a4c0f9d74c8e925f04e5a4a7c7c`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** an existing consumer needs compatibility with the full configurable scanner suite and has reviewed the combined authority; new baseline adoption should use `ecosystem-baseline.yml`.

## Authority And Execution

The required caller cap depends on enabled jobs. A manual or non-PR default run needs `actions: read` and `contents: read`. Add `pull-requests: write` when Dependency Review runs on pull requests. Add `security-events: write` only for `publish-sarif`, CodeQL, Scorecard, or Slither publication; Scorecard additionally needs `id-token: write`. CodeQL and Slither may execute project-controlled build behavior. AI is not part of this umbrella.

The workflow combines read-only scanners, PR publication, Security-tab publication, OIDC publication, and opt-in build analysis. It is therefore classified `legacy-mixed`, not a single release-eligible trust tier.

The caller controls the event. Dependency Review runs only on pull requests;
SBOM and Scorecard run only outside pull requests. Network access and fork
behavior vary by enabled child, so fork PRs should use the Ecosystem Baseline
instead of this combined authority surface.

## Inputs

**Declared secrets:** none

### Evaluation Selection

| Input | Default | Purpose |
|---|---:|---|
| `enable-semgrep` | `true` | Run Semgrep |
| `enable-actions-security` | `true` | Run Zizmor workflow analysis |
| `enable-codeql` | `false` | Run CodeQL build analysis |
| `enable-dependencies` | `true` | Run dependency scan |
| `enable-secrets` | `true` | Run Gitleaks |
| `enable-iac` | `true` | Run IaC scan |
| `enable-licenses` | `true` | Run license scan |
| `enable-dependency-review` | `true` | Run on pull requests only |
| `enable-sbom` | `true` | Run outside pull requests |
| `enable-scorecard` | `false` | Run outside pull requests |
| `enable-slither` | `false` | Run Slither |

### Authority And Shared Configuration

| Input | Default | Purpose |
|---|---:|---|
| `skip-dirs` | `node_modules` | Trivy exclusions |
| `publish-sarif` | `false` | Publish dependency SARIF from a separate job |
| `actions-security-blocking` | `false` | Gate Zizmor findings |
| `semgrep-blocking` | `false` | Gate Semgrep findings |
| `secrets-blocking` | `true` | Gate Gitleaks findings |
| `dependency-blocking` | `false` | Gate dependency findings |
| `dependency-severity` | `CRITICAL,HIGH,MEDIUM` | Dependency severities |
| `iac-blocking` | `false` | Gate IaC findings |
| `iac-severity` | `CRITICAL,HIGH,MEDIUM` | IaC severities |
| `license-blocking` | `false` | Gate license findings |
| `license-severity` | `CRITICAL,HIGH` | License severities |
| `dependency-review-fail-on-severity` | `high` | Dependency Review threshold |
| `deny-licenses` | `GPL-3.0, AGPL-3.0` | Denied licenses |
| `codeql-languages` | `["javascript-typescript"]` | CodeQL language array |
| `slither-target` | `.` | Slither target |
| `slither-args` | Empty | Extra Slither arguments |
| `solc-version` | `0.8.13` | Solidity compiler |
| `slither-fail-on` | `none` | Slither threshold |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no umbrella `workflow_call` outputs and no single Profile Conclusion. Each enabled child workflow owns its summary, annotations, provider alerts, and artifacts. `publish-sarif` adds dependency SARIF publication when the caller grants `security-events: write`.

## Completion And Gating

Each child job applies its own completion and finding-gate semantics. Event conditions skip Dependency Review on non-PR events and skip SBOM/Scorecard on PRs. Because there is no aggregate result, consumers must inspect every enabled job and cannot infer whole-pipeline completeness from one check.

## Immutable Usage

```yaml
name: Legacy security pipeline

on:
  workflow_dispatch:

jobs:
  security:
    permissions:
      actions: read
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/security-pipeline.yml@c95d54087ff3a4783aea814776243990d9778c93
```

For pull-request use, add `pull-requests: write` for Dependency Review. Add `security-events: write` only when enabling a Security-tab publisher, and add `id-token: write` only for Scorecard publication. Enabling CodeQL or Slither opts into build-analysis risk and should be reviewed separately.

## Limitations

The umbrella does not emit one Evidence Bundle or authoritative completion result. Its caller permission cap covers all enabled nested jobs, and several paths combine analysis with publication authority. Prefer the Ecosystem Baseline plus separately authorized privileged workflows for new deployments.

## Compatibility

This is a pre-v1 legacy compatibility surface with no deprecated inputs. Removing or renaming an enable flag, forwarding input, nested workflow, or event condition requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/security-pipeline.yml)
- [Ecosystem Baseline](ecosystem-baseline.md)
- [Execution trust](../reference/execution-trust.md)
- [Current contracts](../reference/current-contracts.md#security-pipeline-umbrella)
