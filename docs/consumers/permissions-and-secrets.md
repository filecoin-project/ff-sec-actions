# Permissions And Secrets

**For:** a Consumer Engineer reviewing workflow authority before adoption.

**Outcome:** the smallest practical authority for each evaluation, with
untrusted PR behavior understood.

## Rules

- Grant permissions per job or called workflow, not broadly for every job.
- Use `contents: read` as the default.
- Grant `pull-requests: write` only to the job that posts or updates comments.
- Grant `security-events: write` only to jobs that upload SARIF.
- Grant `id-token: write` only to Scorecard or another explicitly documented
  OIDC consumer.
- Set `persist-credentials: false` on every checkout.
- Do not expose secrets to a job that executes untrusted repository content.

## Current Capability Matrix

| Capability | Secret | Write authority | Executes project code? |
|---|---|---|---|
| AI code review | `ANTHROPIC_API_KEY` | PR comment write when enabled | No; reads metadata and diff through API |
| Semgrep | None | SARIF upload when enabled | Analyzes checked-out files; does not intentionally build the project |
| CodeQL | None | Security-event upload | Autobuild can execute project build behavior |
| Dependency evidence | None | SARIF upload when enabled | No; inspects manifests and lockfiles, with build-dependent reachability explicitly excluded |
| Gitleaks | None | Artifact behavior | Scans the PR range or repository history with a checksum-verified CLI |
| Trivy IaC | None | SARIF upload when enabled | Analyzes configuration files |
| License/SBOM | None | Artifact upload | No; source-manifest evidence may omit build-generated or runtime-loaded packages |
| Scorecard | None | OIDC and security-event upload | Does not intentionally execute project code |
| Slither | None | SARIF upload when enabled | Builds/analyzes Solidity and can involve project build configuration |

G0-02 and G0-03 enforce exact job permissions, safe checkout, and non-executing
dependency, license, and SBOM inspection. The umbrella caller still grants an
upper cap; each nested job reduces that cap to its reviewed policy.

## Fork Pull Requests

The tested fork-safe caller explicitly caps the token at `contents: read` and
does not forward secrets. Therefore:

- the Gitleaks CLI and other secretless scanner jobs can run when repository
  policy allows, including PR-diff scanning for forks;
- AI review cannot use the Anthropic key under a normal fork
  `pull_request` event;
- a missing secret must be represented as skipped or incomplete, not clean;
- do not switch to `pull_request_target` if any step checks out or executes the
  fork head.

See the executable [fork pull-request safety contract](../reference/fork-pr-safety.md)
for the exact five-evaluation fixture and its boundary tests.

## Next

- [Start a pilot](quickstart.md)
- [Interpret results](understand-results.md)
- [Review the target security architecture](../ECOSYSTEM-SECURITY-DECISION-MAP.md#execution-trust-isolate-untrusted-repository-content)
