# Slither

**Workflow:** `sec-slither.yml`  
**Status:** pre-v1 privileged build analysis  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a Solidity or Foundry project needs Slither detectors and accepts compiler/submodule execution risk.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `actions: read`, `contents: read`, `security-events: write` |
| Secrets | None |
| Consumer code execution | Possible through compiler, framework configuration, and recursively checked-out submodules |
| Network | GitHub actions, submodule origins, Foundry/solc downloads, and Code Scanning |
| Events and forks | Caller-controlled contexts; untrusted PRs and forks are not recommended until build execution and publication authority are separated |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `target` | `.` | Contract directory or Slither target |
| `slither-config` | `slither.config.json` | Configuration used only when present |
| `slither-args` | Empty | Additional Slither CLI arguments |
| `solc-version` | `0.8.13` | Solidity compiler version |
| `fail-on` | `none` | `none`, `low`, `medium`, `high`, `all`, or `config` |

## Outputs And Evidence

There are no `workflow_call` outputs. `slither-results` contains SARIF. When `ENABLE_GHAS='true'`, SARIF is also uploaded to GitHub Code Scanning. Artifact retention follows the Consumer Project's Actions setting; uploaded alerts follow its GitHub Code Security settings.

## Completion And Gating

`fail-on` controls finding failure. Checkout, submodule, compiler, analyzer, or SARIF publication errors can fail the job. This is provider-native rather than a normalized Evaluation Result.

## Immutable Usage

```yaml
jobs:
  slither:
    permissions:
      actions: read
      contents: read
      security-events: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-slither.yml@c95d54087ff3a4783aea814776243990d9778c93
    with:
      target: contracts
```

## Limitations

The current workflow is `legacy-mixed`: untrusted build analysis and Security-tab write authority share one job. Findings depend on compiler compatibility, dependency resolution, and Slither's supported detectors.

## Compatibility

This is a pre-v1 privileged-analysis contract with no deprecated inputs. Changing compiler/build behavior, detector inputs, or publication authority requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-slither.yml)
- [Execution trust](../reference/execution-trust.md)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
