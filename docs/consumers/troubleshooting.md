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
SARIF, and artifacts. To gate findings, set the scanner-specific `*-blocking`
input documented in the [current contract](../reference/current-contracts.md).
Operational failure and malformed SARIF fail independently of that setting.

## Results Are Missing From The Security Tab

- The Ecosystem Baseline intentionally does not publish to the Security tab;
  download its SARIF and `ecosystem-baseline-evidence` run artifacts instead.
- Confirm the job received `security-events: write`.
- Confirm GitHub Code Security is available for the repository.
- For the privileged full-suite example, confirm `ENABLE_GHAS='true'` is being
  forwarded to the explicit `publish-sarif` input.
- Check the workflow artifact even when SARIF upload is unavailable.

## Dependency, License, Or SBOM Work Fails

- Confirm the repository contains a supported manifest or lockfile and that it
  is not excluded by `skip-dirs`.
- Do not add package installation to the baseline workflow as a workaround.
- If complete evidence requires installation or a build, record the baseline
  limitation and use a separately isolated Privileged Build Analysis.

## Profile Detection Reports A Coverage Gap

- Open the job summary or `profile-detection.json` and inspect the component
  path, recognized marker, and current limitations.
- Select the closest Security Profile manually when the component is supported
  but its signal is intentionally indirect.
- If the signal is reusable across Consumer Projects, add a minimal fixture and
  detector rule to the Control Repository; do not suppress the gap without
  recording the manual selection.
- Do not interpret zero gaps as proof that every directory was classified.

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
