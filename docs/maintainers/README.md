# Platform Maintainer Guide

**For:** people changing workflows, actions, prompts, schemas, profiles,
examples, documentation, or releases in the Control Repository.

**Outcome:** a change that preserves consumer compatibility, trust boundaries,
and documentation contracts.

## Start Here

1. Read the shared [domain language](../../CONTEXT.md).
2. Read the [decision map](../ECOSYSTEM-SECURITY-DECISION-MAP.md).
3. Read the accepted [distribution model](../decisions/distribution-model.md).
4. Read the [documentation architecture](../DOCUMENTATION-ARCHITECTURE.md).
5. Identify whether the change affects a consumer interface, execution trust,
   Evaluation Result, Security Profile, or release graph.
6. Run `bash scripts/check-docs.sh` for documentation changes.

## Repository Responsibilities

| Area | Owns |
|---|---|
| `actions/` | Composite action inputs, outputs, and implementation |
| `.github/workflows/` | Runners, permissions, secret plumbing, and reusable workflow contracts |
| `prompts/` | Shared and Filecoin-specific AI review behavior |
| `examples/` | Executable consumer contracts |
| `docs/` | Consumer, maintainer, operator, and reference journeys |
| `scripts/` | Local validation and development tooling |

## Change Rules

- Treat workflow/action inputs, outputs, defaults, and completion behavior as
  versioned consumer contracts.
- Give every workflow explicit least privilege.
- Treat PR content, repository files, diffs, titles, and descriptions as
  untrusted.
- Do not execute project code merely to inspect it.
- Pin every external execution dependency immutably.
- Keep composite actions thin and put testable logic in scripts.
- Update or add an executable example when a consumer-facing capability
  changes.
- Update documentation in the same change; do not defer contract corrections.

## Before Opening A Pull Request

Run the checks that currently exist:

```sh
bash scripts/check-docs.sh
actionlint .github/workflows/*.yml examples/*.yml
shellcheck actions/**/scripts/*.sh scripts/*.sh
jq empty actions/**/scripts/*.json
```

The repository is still adding automated CI and adversarial fixtures. The
[verification-system ticket](../ECOSYSTEM-SECURITY-DECISION-MAP.md#verification-system-prove-safety-and-detection-before-release)
defines the complete target.

## Release Status

There is no stable v1. Do not introduce documentation that implies `@v1`
exists, and do not claim that pinning the current umbrella transitively pins
nested workflows. Release integrity is a prerequisite for public adoption.
