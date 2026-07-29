# Consumer Quickstart

**For:** a Consumer Engineer evaluating `ff-sec-actions` in one repository.

**Outcome:** a pilot workflow with explicit permissions and a result you know
how to interpret.

## Before You Start

This repository has no stable v1 release. The example pins a reviewed pre-v1
commit whose nested workflows, actions, assets, tools, and containers form an
[immutable release graph](../reference/release-integrity.md). Use this
quickstart in a sandbox or approved pilot while the remaining G0 release gates
are completed.

You need:

- permission to add a workflow under `.github/workflows/`;
- GitHub Actions enabled in the Consumer Project;
- an `ANTHROPIC_API_KEY` only if you enable AI review;
- GitHub Code Security availability only if you enable features that require
  it in a private repository.

## 1. Choose The Evaluation

| Goal | Starting point | Authority |
|---|---|---|
| Run the current scanner suite | [Security pipeline example](../../examples/consumer-security-pipeline.yml) | Repository contents plus explicitly declared result permissions |
| Review a PR with Filecoin context | [AI review example](../../examples/consumer-ai-code-review.yml) | PR diff read, optional PR comment write, Anthropic API key |
| Run AI review on demand | [Manual AI example](../../examples/consumer-manual-ai-code-review.yml) | Same as AI review, initiated manually |

If you are unsure, consult [Choose a Security Profile](choose-a-profile.md).
Security Profiles are still being designed; current examples expose individual
tools rather than a stable profile contract.

## 2. Inspect Before Copying

Before adding an example:

1. Read its `permissions` block.
2. Confirm whether it checks out repository content.
3. Confirm whether it installs or executes project dependencies.
4. Confirm which secrets are required and what happens on fork PRs.
5. Confirm whether scanners are advisory or merge-blocking.
6. Keep the full commit pin and review the graph diff before upgrading it.

See [Permissions and secrets](permissions-and-secrets.md) for the current trust
matrix.

## 3. Start Advisory

Do not make a new evaluation a required merge gate on its first run. Start in
advisory mode, inspect tool failures separately from findings, tune legitimate
suppressions, and then define a Merge Gate.

Scanner adapters and AI review emit the pre-v1 Completion Status, but the
umbrella does not yet aggregate every job into one Evidence Bundle. Inspect
every job and artifact rather than treating the parent result as a complete
security verdict.

## 4. Interpret The First Run

Use [Understand Evaluation Results](understand-results.md) to distinguish:

- a completed evaluation with no findings;
- a completed evaluation with advisory findings;
- a skipped evaluation;
- a tool or permission failure;
- incomplete AI coverage or refusal.

## What Can Go Wrong?

- **A referenced `v1` cannot be found:** no stable v1 has been published.
- **A fork PR cannot access AI review:** fork workflows do not receive the
  Anthropic secret.
- **A scanner is green despite findings:** advisory is the default. Enable the
  documented scanner-specific gate only after observing and triaging results;
  tool failure remains blocking independently.
- **SARIF is missing:** GitHub Code Security availability and
  `security-events: write` affect upload behavior.

Use [Troubleshooting](troubleshooting.md) for the first diagnostic checks. The
task guides here are authoritative.

## Next

- [Choose a Security Profile](choose-a-profile.md)
- [Understand Evaluation Results](understand-results.md)
- [Permissions and secrets](permissions-and-secrets.md)
- [Troubleshooting](troubleshooting.md)
