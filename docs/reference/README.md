# Reference

This index points to the current source contracts. Generated reference pages
will replace manual tables after the evaluation and profile schemas stabilize.

## Consumer-Facing Contracts

- [Current pre-v1 contracts](current-contracts.md)
- [Execution trust tiers](execution-trust.md)
- [Evaluation Result contract](evaluation-result.md)
- [Release integrity](release-integrity.md)

## Reusable Workflows

- [AI code review](../../.github/workflows/ai-code-review.yml)
- [Security pipeline](../../.github/workflows/security-pipeline.yml)
- [GitHub Actions security](../../.github/workflows/sec-actions.yml)
- [CodeQL](../../.github/workflows/sec-codeql.yml)
- [Dependency scan](../../.github/workflows/sec-dependencies.yml)
- [Dependency review](../../.github/workflows/sec-dependency-review.yml)
- [IaC scan](../../.github/workflows/sec-iac.yml)
- [License scan](../../.github/workflows/sec-licenses.yml)
- [SBOM](../../.github/workflows/sec-sbom.yml)
- [Scorecard](../../.github/workflows/sec-scorecard.yml)
- [Secret scan](../../.github/workflows/sec-secrets.yml)
- [Semgrep](../../.github/workflows/sec-semgrep.yml)
- [Slither](../../.github/workflows/sec-slither.yml)

## Composite Actions

- [AI code-review metadata](../../actions/ai-code-review/action.yml)
- [Secretless Gitleaks adapter](../../actions/gitleaks-scan/action.yml)
- [AI result schema](../../actions/ai-code-review/scripts/schema.json)
- [Scanner outcome adapter](../../actions/scanner-outcome/action.yml)

## Schemas

- [Evaluation Result](../../schemas/evaluation-result.schema.json)

## Prompts

- [Base reviewer](../../prompts/base-reviewer.md)
- [Filecoin domain](../../prompts/filecoin.md)
- [Generic domain](../../prompts/default.md)
- [Threat-model design](../../prompts/base-threat-modeler.md)

## Consumer Examples

- [AI review](../../examples/consumer-ai-code-review.yml)
- [Manual AI review](../../examples/consumer-manual-ai-code-review.yml)
- [Security pipeline](../../examples/consumer-security-pipeline.yml)

## Stability

These source files document current pre-v1 behavior. Consumer entrypoints and
their complete execution graph are immutable when selected by a reviewed full
commit; see the [release-integrity contract](release-integrity.md).
