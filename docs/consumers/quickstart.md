# Consumer Quickstart

**For:** a Consumer Engineer evaluating `ff-sec-actions` in one repository.

**Outcome:** a pilot workflow with explicit permissions and a result you know
how to interpret.

## Before You Start

This is a consumer-testable alpha, not a stable v1. The example selects one
reviewed commit whose complete nested execution graph is immutable. Use it in a
sandbox or approved pilot and keep the full commit pin intact.

The Ecosystem Baseline needs:

- permission to add `.github/workflows/security-baseline.yml`;
- GitHub Actions enabled with Linux hosted runners;
- `contents: read` and `actions: read` for the baseline job;
- outbound HTTPS access to GitHub releases and the pinned scanner registries;
- organization policy allowing `filecoin-project/ff-sec-actions`, GitHub-owned
  actions, `aquasecurity/trivy-action`, and their immutable references.

It needs no repository or organization secret, OIDC, GitHub Code Security
license, package installation, build command, or write permission. An unrelated
`ENABLE_GHAS` repository variable does not change the baseline.

## Install

1. Open the [immutable consumer example](../../examples/consumer-ecosystem-baseline.yml).
2. Copy it unchanged to `.github/workflows/security-baseline.yml` in the
   Consumer Project.
3. Commit it on a pilot branch and open a pull request.
4. Confirm the workflow uses ordinary `pull_request`, not
   `pull_request_target`.

The example starts its configurable workflow, dependency, secret, IaC, and
static-analysis gates advisory while keeping `require-complete: true`. Tool
failure, missing evidence, a skipped required evaluation, or malformed output
still fails `Profile Conclusion`.

## Verify The First Run

The run should contain five evaluation jobs plus `Profile Conclusion`:

- GitHub Actions definitions with Zizmor;
- Git history or the pull-request range with Gitleaks;
- dependency manifests and lockfiles with Trivy;
- infrastructure configuration with Trivy;
- the versioned ecosystem Semgrep rules.

Open `Profile Conclusion`, then download `ecosystem-baseline-evidence`. The
bundle must contain all five Evaluation Results with explicit completion,
coverage, tool version, findings count, and evidence references.

Accept the installation only when:

- every required Evaluation Result is present and complete;
- `Profile Conclusion` reflects the bundle rather than an individual scanner;
- advisory findings are visible and have usable file locations;
- no job received a secret or write-capable token;
- a fork pull request can run under the same read-only model;
- the project owner has recorded the installed commit and rollback commit.

Do not make the check required until this first run is understood. After that,
configure branch protection to require `Profile Conclusion`, not the individual
scanner job names.

## Enable Finding Gates

Turn on only the gates the project is ready to enforce:

- `actions-security-blocking` for workflow-definition findings;
- `dependency-blocking` for dependency vulnerabilities;
- `secrets-blocking` for Gitleaks findings after historical results are triaged;
- `iac-blocking` for infrastructure findings;
- `static-analysis-blocking` for ecosystem Semgrep findings.

Completion remains required independently of every finding gate. Before enabling
the secret gate, revoke or rotate real credentials and suppress only verified
false positives.

## Upgrade

Review the Control Repository diff and immutable release-graph result, then
change only the 40-character commit after `ecosystem-baseline.yml@` in the
consumer workflow. Run the same acceptance checks before making the new result
required.

## Roll Back

Restore the previously recorded 40-character commit in the consumer workflow.
Do not replace it with a branch or mutable tag. Re-run the workflow and confirm
`Profile Conclusion` and `ecosystem-baseline-evidence` are produced by the
restored graph.

## What Can Go Wrong?

- **Workflow not found:** confirm the full commit exists and organization Actions
  policy allows public reusable workflows.
- **Evaluation is incomplete:** inspect the individual Evaluation Result for a
  tool download, registry, permission, or unsupported-runner failure.
- **Findings are green:** advisory is the initial policy; completion and finding
  gates are separate.
- **No Security tab results:** the Ecosystem Baseline intentionally stores SARIF
  as run artifacts without `security-events: write`. Use the privileged pipeline
  with explicit `publish-sarif` authority if Security-tab publication is needed.

Use [Troubleshooting](troubleshooting.md) for detailed diagnostic checks.

## Next

- [Choose a Security Profile](choose-a-profile.md)
- [Understand Evaluation Results](understand-results.md)
- [Permissions and secrets](permissions-and-secrets.md)
- [Troubleshooting](troubleshooting.md)
