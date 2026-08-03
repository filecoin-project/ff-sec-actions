# Consumable Workflow Catalog

**For:** Consumer Engineers and reviewers evaluating reusable security workflows.

**Outcome:** choose a workflow by coverage and authority, then inspect its complete consumer contract without reading implementation YAML.

All workflows are pre-v1 and must be consumed at a reviewed full commit SHA. Start with the secretless [Ecosystem Baseline](ecosystem-baseline.md) unless a narrower evaluation or explicitly privileged analysis is required.

## Recommended Starting Points

| Workflow | Purpose | Trust posture |
|---|---|---|
| [Ecosystem Baseline](ecosystem-baseline.md) | Five normalized, secretless evaluations plus one Profile Conclusion | Read-only; does not execute Consumer Project code |
| [Evaluation Pipeline](evaluation-pipeline.md) | Minimal dependency-evaluation aggregation example | Read-only vertical slice |
| [AI Code Review](ai-code-review.md) | Diff-focused Filecoin-aware review | External provider secret and optional PR comment write |

## Individual Evaluations

| Workflow | Evaluates | Primary evidence |
|---|---|---|
| [GitHub Actions Security](sec-actions.md) | Workflow/action definitions | Normalized result and Zizmor SARIF |
| [CodeQL](sec-codeql.md) | Supported source languages | GitHub Code Scanning alerts |
| [Dependency Scan](sec-dependencies.md) | Manifest and lockfile vulnerabilities | Normalized result and Trivy SARIF |
| [Dependency Review](sec-dependency-review.md) | Dependencies introduced by a pull request | PR summary and annotations |
| [IaC Scan](sec-iac.md) | Infrastructure misconfiguration | Normalized result and Trivy SARIF |
| [License Compliance](sec-licenses.md) | Manifest and lockfile license evidence | Normalized result and Trivy SARIF |
| [SBOM Generation](sec-sbom.md) | Source-visible package inventory | Downloadable SBOM |
| [OpenSSF Scorecard](sec-scorecard.md) | Repository supply-chain posture | Scorecard SARIF and Security alerts |
| [Secret Scan](sec-secrets.md) | PR commit range or full Git history | Redacted normalized result and Gitleaks SARIF |
| [Semgrep SAST](sec-semgrep.md) | Ecosystem Baseline source patterns | Normalized result and Semgrep SARIF |
| [Slither](sec-slither.md) | Solidity/Foundry contracts | Slither SARIF and Security alerts |

## Umbrella Workflow

[Security Pipeline](security-pipeline.md) is the legacy mixed-authority umbrella. It is useful for compatibility review, but new secretless adoption should prefer the Ecosystem Baseline and add privileged workflows separately.

## Review Rules

- Compare the declared permission cap with the jobs you intend to enable.
- Treat project execution, secrets, write permissions, OIDC, and external transfer as separate authority decisions.
- Confirm Completion Status independently from finding severity or Merge Gate outcome.
- Preserve raw and normalized evidence long enough for triage and audit.
- Advance a workflow SHA only after reviewing its complete immutable dependency graph.

## Next

- [Consumer quickstart](../consumers/quickstart.md)
- [Choose a Security Profile](../consumers/choose-a-profile.md)
- [Permissions and secrets](../consumers/permissions-and-secrets.md)
