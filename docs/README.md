# Documentation

Choose the path that matches the work you are doing. The root
[README](../README.md) gives the short project overview; this page is the
complete navigation index.

## Consumer Engineers

Use these pages when adopting or operating security evaluation inside one
Consumer Project:

- [Quickstart](consumers/quickstart.md)
- [Adopt the Ecosystem Baseline](consumers/ecosystem-baseline.md)
- [Choose a Security Profile](consumers/choose-a-profile.md)
- [Understand Evaluation Results](consumers/understand-results.md)
- [Permissions and secrets](consumers/permissions-and-secrets.md)
- [Troubleshooting](consumers/troubleshooting.md)
- [Legacy consumer-documentation entry point](CONSUMING.md)

## Platform Maintainers

Use the [Platform Maintainer guide](maintainers/README.md) when changing or
releasing the Control Repository.

- [Shared domain language](../CONTEXT.md)
- [G0 trustworthy-foundation gate](maintainers/g0-gate.md)
- [Standalone script conventions](../scripts/README.md)
- [AI review development harness](../scripts/dev/README.md)

## Rollout Operators

Use the [Rollout Operator guide](operators/README.md) when coordinating pilots,
policy, exceptions, upgrades, and rollback across projects.

## Reference

- [Reference index](reference/README.md)
- [Current pre-v1 workflow contracts](reference/current-contracts.md)
- [Execution trust tiers](reference/execution-trust.md)
- [Evaluation Result contract](reference/evaluation-result.md)
- [Evaluation adapter](reference/evaluation-adapter.md)
- [Evidence Bundle and profile conclusion](reference/evidence-bundle.md)
- [Ecosystem Baseline static rules](reference/ecosystem-baseline-rules.md)
- [Release integrity](reference/release-integrity.md)
- [Fork pull-request safety](reference/fork-pr-safety.md)
- [Documentation architecture](DOCUMENTATION-ARCHITECTURE.md)
- [Ecosystem security decision map](ECOSYSTEM-SECURITY-DECISION-MAP.md)
- [Distribution model decision](decisions/distribution-model.md)
- [Machine-readable implementation roadmap](../roadmap/README.md)

## Executable Examples

- [Secretless Ecosystem Baseline](../examples/consumer-ecosystem-baseline.yml)
- [AI review on pull requests](../examples/consumer-ai-code-review.yml)
- [AI review on demand](../examples/consumer-manual-ai-code-review.yml)
- [Security scanner pipeline](../examples/consumer-security-pipeline.yml)

## Current Planning Status

This repository is pre-v1. The decision map is authoritative for product
decisions, and the machine-readable roadmap is authoritative for implementation
order and status. Planned pages and profiles are not documented as available
until their implementation and contract tests exist.
