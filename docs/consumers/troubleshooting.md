# Troubleshooting

**For:** a Consumer Engineer diagnosing installation, permission, completion,
or result-visibility problems.

**Outcome:** identify whether the problem is a reference, event, authority,
tool, or result-interpretation failure.

## Workflow Cannot Be Found

- Confirm the slug is `filecoin-project/ff-sec-actions`.
- Confirm the referenced commit or tag exists.
- If the Control Repository is private, confirm the Consumer Project is
  permitted to use it.
- Do not substitute `@v1`: no v1 release exists yet.

## AI Review Says A Secret Is Missing

- Confirm `ANTHROPIC_API_KEY` exists in the Consumer Project or is shared with
  it by the organization.
- Fork PR workflows do not receive ordinary repository or organization
  secrets.
- Do not use `pull_request_target` if any job checks out or executes untrusted
  PR content.

## A Job Was Skipped

- Check the caller event. Dependency review runs on pull requests, while SBOM
  and Scorecard jobs are normally excluded from pull requests.
- Check scanner enablement inputs and draft-PR conditions.
- Treat an unexpected skip as incomplete coverage, not zero findings.

## A Scanner Is Green Despite Findings

Several current scanners are advisory. Inspect the step conclusion, logs,
SARIF, and artifacts. The G0 remediation work will make finding exit codes and
umbrella blocking inputs consistent.

## Results Are Missing From The Security Tab

- Confirm the job received `security-events: write`.
- Confirm GitHub Code Security is available for the repository.
- Confirm the workflow's `ENABLE_GHAS` compatibility variable is set where the
  current workflow expects it.
- Check the workflow artifact even when SARIF upload is unavailable.

## Dependency, License, Or SBOM Work Fails

- Confirm the selected package manager matches the repository.
- Prefer `package-manager: none` for the current safe baseline.
- Current npm/pnpm modes install dependencies and may run lifecycle scripts;
  do not enable them on untrusted content until G0 hardening lands.

## Escalation Information

When asking a Platform Maintainer for help, include:

- Consumer Project and workflow run URL;
- event type and whether the PR is from a fork;
- referenced `ff-sec-actions` commit or tag;
- enabled evaluations and relevant inputs;
- job and step conclusion;
- whether the failure is repeatable;
- sanitized error output with secrets and proprietary code removed.

Do not put suspected vulnerability details or secrets in a public issue. The
formal private reporting route is a public-v1 governance requirement.

## Next

- [Return to the quickstart](quickstart.md)
- [Understand results](understand-results.md)
- [Review permissions and secrets](permissions-and-secrets.md)
