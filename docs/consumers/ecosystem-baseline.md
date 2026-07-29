# Adopt The Ecosystem Baseline

**For:** a Consumer Engineer who wants the broad, secretless starting profile.

**Outcome:** one reusable workflow runs five non-executing evaluations and
produces one Evidence Bundle plus the stable `Profile Conclusion` check.

## What Runs

| Evaluation | Scope | Default gate |
|---|---|---|
| Zizmor | GitHub workflow and action definitions | Advisory findings; completion required |
| Gitleaks | PR commit range or full history | Configurable; advisory in the consumer alpha |
| Trivy dependencies | Recursive manifests and lockfiles | Advisory findings; completion required |
| Trivy IaC | Recognized infrastructure configuration | Advisory findings; completion required |
| Semgrep | Versioned conservative Go, Rust, JavaScript/TypeScript, Solidity, and Dockerfile rules | Advisory findings; completion required |

All jobs run without repository or organization secrets, OIDC, write authority,
shared caches, self-hosted runners, package installation, builds, or project
commands. The profile is appropriate for ordinary fork `pull_request` events.

## What Does Not Run

The baseline does not install dependencies, run tests, compile code, execute
build scripts, resolve runtime cloud state, or claim complete language coverage.
Installed/build-generated dependencies and unsupported source patterns appear as
limitations in the individual Evaluation Results and aggregate bundle.

## Start Advisory

Copy the [immutable consumer example](../../examples/consumer-ecosystem-baseline.yml).
Keep `require-complete: true`; it prevents a missing or broken scanner from
looking clean. Leave finding gates advisory for the first runs, triage noise,
then enable the relevant `*-blocking` input.

The available gates are `actions-security-blocking`, `dependency-blocking`,
`secrets-blocking`, `iac-blocking`, and `static-analysis-blocking`. Treat
Gitleaks findings as incident evidence even during advisory rollout: rotate
real credentials before addressing source or history.

The required branch check is `Profile Conclusion`, not the individual scanner
job names. Download `ecosystem-baseline-evidence` when investigating a result.

## Next

- [Install and verify the first run](quickstart.md)
- [Understand results](understand-results.md)
- [Permissions and secrets](permissions-and-secrets.md)
- [Troubleshooting](troubleshooting.md)
