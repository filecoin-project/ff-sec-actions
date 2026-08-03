# CodeQL

**Workflow:** `sec-codeql.yml`<br>
**Status:** pre-v1 `legacy-mixed`; target is separated privileged build analysis and publication<br>
**Introduced:** commit `f816e783c0230a4c0f9d74c8e925f04e5a4a7c7c`<br>
**Owner:** Filecoin ecosystem security platform maintainers<br>
**Use when:** GitHub Code Security is available and supported-language semantic analysis justifies build execution and Security-tab publication.

## Authority And Execution

| Concern | Contract |
|---|---|
| Permissions | `contents: read`, `security-events: write` |
| Secrets | None |
| Consumer code execution | Possible: CodeQL autobuild may execute project-controlled build behavior |
| Network | GitHub actions, language package registries, and Code Scanning |
| Events and forks | Caller-controlled contexts; review product availability, build trust, and write-token restrictions before enabling PRs or forks |
| Current trust tier | `legacy-mixed`; not release eligible until build analysis and publication are separated |

## Inputs

**Declared secrets:** none

| Input | Default | Purpose |
|---|---|---|
| `languages` | `["javascript-typescript"]` | JSON array of CodeQL languages |
| `queries` | `security-extended` | CodeQL query suite |

## Outputs And Evidence

**Declared workflow outputs:** none

There are no `workflow_call` outputs or repository artifact. Results are provider-native GitHub Code Scanning alerts with query help and source locations. Alert retention follows the Consumer Project's GitHub Code Security settings.

## Completion And Gating

CodeQL initialization, autobuild, analysis, and upload control job success. Alert gating follows the Consumer Project's GitHub Code Security configuration rather than a workflow input.

## Immutable Usage

```yaml
name: CodeQL privileged analysis

on:
  workflow_dispatch:

jobs:
  codeql:
    permissions:
      contents: read
      security-events: write
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-codeql.yml@c95d54087ff3a4783aea814776243990d9778c93
    with:
      languages: '["go"]'
```

## Limitations

The current workflow mixes build execution with publication authority and is classified `legacy-mixed`; do not run it on untrusted code until that authority is separated. GitHub Code Security availability varies by repository.

## Compatibility

This is a pre-v1 provider-native contract with no deprecated inputs. Changing language/query inputs or the Security-tab publication behavior requires migration guidance and a new reviewed immutable pin.

## Source

- [Workflow source](../../.github/workflows/sec-codeql.yml)
- [Execution trust](../reference/execution-trust.md)
- [Current contracts](../reference/current-contracts.md#individual-scanner-workflows)
