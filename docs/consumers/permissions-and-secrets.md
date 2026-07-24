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
- Set `persist-credentials: false` whenever checked-out content or dependencies
  can execute.
- Do not expose secrets to a job that executes untrusted repository content.

## Current Capability Matrix

| Capability | Secret | Write authority | Executes project code? |
|---|---|---|---|
| AI code review | `ANTHROPIC_API_KEY` | PR comment write when enabled | No; reads metadata and diff through API |
| Semgrep | None | SARIF upload when enabled | Analyzes checked-out files; does not intentionally build the project |
| CodeQL | None | Security-event upload | Autobuild can execute project build behavior |
| Dependency audit | None | SARIF upload when enabled | Current npm/pnpm path installs dependencies and may run lifecycle scripts |
| Gitleaks | License may be required | Security-event/artifact behavior | Scans repository history |
| Trivy IaC | None | SARIF upload when enabled | Analyzes configuration files |
| License/SBOM | None | Artifact upload | Current npm/pnpm path installs dependencies and may run lifecycle scripts |
| Scorecard | None | OIDC and security-event upload | Does not intentionally execute project code |
| Slither | None | SARIF upload when enabled | Builds/analyzes Solidity and can involve project build configuration |

The G0 work will remove unnecessary lifecycle execution and make each called
workflow reduce its own permissions. Until then, do not use the broad umbrella
permission example as proof that every nested job needs every permission.

## Fork Pull Requests

GitHub does not pass ordinary repository or organization secrets to fork PR
workflows, and the token is normally read-only. Therefore:

- secretless scanner jobs can run when repository policy allows;
- AI review cannot use the Anthropic key under a normal fork
  `pull_request` event;
- a missing secret must be represented as skipped or incomplete, not clean;
- do not switch to `pull_request_target` if any step checks out or executes the
  fork head.

## Next

- [Start a pilot](quickstart.md)
- [Interpret results](understand-results.md)
- [Review the target security architecture](../ECOSYSTEM-SECURITY-DECISION-MAP.md#execution-trust-isolate-untrusted-repository-content)
