# Permission-Free Zizmor Adapter

**Stability:** consumer-testable pre-v1 alpha. Introduced in the optimization
release candidate; its inputs and outputs may change before v1.

**Owner:** Filecoin ecosystem security platform maintainers. A repository-wide
CODEOWNERS policy has not yet been established and remains a pre-v1 governance
gap.

[`actions/zizmor-scan`](../../actions/zizmor-scan/action.yml) inspects GitHub
Actions workflow and action definitions with Zizmor 1.28.0 in offline mode. It
separates operational success from findings and does not require GitHub Code
Security or `security-events: write`.

## Immutable Consumption

The supported Ecosystem Baseline already composes this adapter. Platform
Maintainers needing it inside a custom job can pin the repository action:

```yaml
permissions:
  contents: read

steps:
  - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
    with:
      persist-credentials: false
  - id: zizmor
    uses: filecoin-project/ff-sec-actions/actions/zizmor-scan@a6c0e17e90c5d2baef63b32e490c1f080ab97add
    with:
      input-path: .
      result-file: ${{ runner.temp }}/zizmor-actions.sarif
```

Do not replace either full commit with a branch or mutable tag. Consumer
Engineers who want the normalized result and stable merge check should use the
[Ecosystem Baseline](../consumers/ecosystem-baseline.md), not this leaf action.

## Authority And Execution Boundary

| Boundary | Behavior |
|---|---|
| Permissions | The adapter calls no GitHub API. A preceding checkout normally needs only `contents: read`. |
| Secrets | None required or read. |
| Network | Downloads a Zizmor release archive from GitHub over HTTPS unless `ZIZMOR_BIN` selects a preinstalled executable. The archive SHA-256 is pinned per supported platform. Zizmor itself runs `--offline`. |
| Consumer code | Parses workflow YAML and action metadata; it does not run project build, package-manager, shell, or lifecycle commands. |

## Inputs

| Input | Required | Default | Meaning |
|---|---:|---|---|
| `input-path` | No | `.` | Repository path containing workflow and action definitions. |
| `config-path` | No | Empty | Explicit Zizmor configuration. Empty disables repository configuration discovery. |
| `result-file` | No | `zizmor-results.sarif` | Runner-local SARIF destination. |

## Outputs And Completion

| Output | Meaning |
|---|---|
| `scanner-outcome` | `success` when Zizmor ran and emitted SARIF, including when it found issues; `failure` for installation or scanner errors. |
| `result-file` | The requested runner-local SARIF path. |

Findings do not fail this leaf action. Its caller must validate SARIF and choose
advisory or blocking policy; the supported `sec-actions.yml` workflow does that
with the Evaluation Adapter. Operational failure is exposed through
`scanner-outcome=failure` so it cannot be represented as zero findings.

The action itself uploads no artifact and sets no retention period. The
supported workflow uploads `evaluation-result-zizmor-actions` using GitHub's
repository-default artifact retention. Raw SARIF remains runner-local unless a
caller explicitly uploads it.

## Events, Forks, And Runners

The action has no event-specific behavior and can run on `pull_request`,
`push`, `schedule`, or `workflow_dispatch`. It is fork-safe under a normal
`pull_request` when the caller keeps read-only permissions and passes no
secrets. Do not switch a consumer workflow to `pull_request_target`.

The verified installer supports GitHub-hosted Linux and macOS runners on x64
and arm64. Other operating systems and architectures fail explicitly. Self-
hosted runners must provide the same basic shell tools and outbound access, or
preinstall Zizmor and select it with `ZIZMOR_BIN`.

## Compatibility And Deprecation

The adapter currently fixes Zizmor at 1.28.0 and uses its SARIF interface.
Changing the tool version, checksums, severity/persona defaults, output shape,
or supported platforms requires fixture verification and a reviewed immutable
pin advance. There is no deprecated input or migration path yet because this
surface is pre-v1.

## Next

- [Adopt the Ecosystem Baseline](../consumers/ecosystem-baseline.md)
- [Understand Evaluation Results](../consumers/understand-results.md)
- [Review release integrity](release-integrity.md)
