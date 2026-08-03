# SBOM Generation

**Workflow:** `sec-sbom.yml`  
**Status:** pre-v1 inventory workflow  
**Introduced:** pre-v1; no stable release tag  
**Owner:** Filecoin ecosystem security platform maintainers  
**Use when:** a project needs a durable source-visible software bill of materials without installing or building dependencies.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read` |
| Secrets and writes | None |
| Consumer code execution | None; Syft inventories checked-out source and manifests |
| Network | GitHub action download and artifact upload |
| Events and forks | Prefer push, schedule, or manual dispatch; the umbrella skips pull requests and fork PRs should not publish artifacts |

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `format` | `cyclonedx-json` | SBOM serialization format |
| `output-file` | `sbom-cyclonedx.json` | Output filename and artifact name |

## Outputs And Evidence

There are no `workflow_call` outputs. The Anchore action uploads the generated SBOM using `output-file` as both filename and artifact name. The artifact uses the Consumer Project's configured GitHub Actions retention.

## Completion And Gating

This workflow is informational inventory. Generation or artifact failure fails the job; package contents do not create a finding gate.

## Immutable Usage

```yaml
jobs:
  sbom:
    permissions:
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-sbom.yml@c95d54087ff3a4783aea814776243990d9778c93
```

## Limitations

Source inspection can miss installed, vendored-at-build, dynamically fetched, or generated dependencies. A build-enhanced SBOM belongs in a separately isolated privileged analysis.

## Compatibility

This is a pre-v1 inventory contract with no deprecated inputs. Changing output formats, artifact naming, or inputs requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-sbom.yml)
- [Current contracts](../reference/current-contracts.md#individual-scanner-workflows)
- [Execution trust](../reference/execution-trust.md)
