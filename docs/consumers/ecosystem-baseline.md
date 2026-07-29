# Adopt The Ecosystem Baseline

**For:** a Consumer Engineer who wants the broad, secretless starting profile.

**Outcome:** one reusable workflow runs five non-executing evaluations and
produces one Evidence Bundle plus the stable `Profile Conclusion` check.

## What Runs

| Evaluation | Scope | Default gate |
|---|---|---|
| Zizmor | GitHub workflow and action definitions | Blocking high-confidence workflow risks |
| Gitleaks | PR commit range or full history | Blocking secret findings |
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

Start from the [reusable workflow contract](../../.github/workflows/ecosystem-baseline.yml);
the immutable consumer example is published from the resulting profile commit.
Keep `require-complete: true`; it prevents a missing or broken scanner from
looking clean. Leave finding gates advisory for the first runs, triage noise,
then enable the relevant `*-blocking` input.

The required branch check is `Profile Conclusion`, not the individual scanner
job names. Download `ecosystem-baseline-evidence` when investigating a result.

## Next

- [Understand results](understand-results.md)
- [Permissions and secrets](permissions-and-secrets.md)
- [Troubleshooting](troubleshooting.md)
