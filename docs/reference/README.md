# Reference

This index points to the current source contracts. Generated reference pages
will replace manual tables after the evaluation and profile schemas stabilize.

## Consumer-Facing Contracts

- [Current pre-v1 contracts](current-contracts.md)
- [Execution trust tiers](execution-trust.md)
- [Evaluation Result contract](evaluation-result.md)
- [Evaluation adapter](evaluation-adapter.md)
- [Evidence Bundle and profile conclusion](evidence-bundle.md)
- [Consumable output contract](consumable-output.md)
- [Ecosystem Baseline static rules](ecosystem-baseline-rules.md)
- [Permission-free Zizmor adapter](zizmor-scan.md)
- [Release integrity](release-integrity.md)
- [Fork pull-request safety](fork-pr-safety.md)
- [Filecoin Security Profile detection](profile-detection.md)

## Reusable Workflows

- [Consumable Workflow Catalog](../workflows/README.md)
- [AI code review](../workflows/ai-code-review.md)
- [Security pipeline](../workflows/security-pipeline.md)
- [Evaluation pipeline vertical slice](../workflows/evaluation-pipeline.md)
- [Ecosystem Baseline](../workflows/ecosystem-baseline.md)
- [GitHub Actions security](../workflows/sec-actions.md)
- [CodeQL](../workflows/sec-codeql.md)
- [Dependency scan](../workflows/sec-dependencies.md)
- [Dependency review](../workflows/sec-dependency-review.md)
- [IaC scan](../workflows/sec-iac.md)
- [License scan](../workflows/sec-licenses.md)
- [SBOM](../workflows/sec-sbom.md)
- [Scorecard](../workflows/sec-scorecard.md)
- [Secret scan](../workflows/sec-secrets.md)
- [Semgrep](../workflows/sec-semgrep.md)
- [Slither](../workflows/sec-slither.md)

## Composite Actions

- [AI code-review metadata](../../actions/ai-code-review/action.yml)
- [Secretless Gitleaks adapter](../../actions/gitleaks-scan/action.yml)
- [Permission-free Zizmor adapter](../../actions/zizmor-scan/action.yml)
- [AI result schema](../../actions/ai-code-review/scripts/schema.json)
- [Scanner outcome adapter](../../actions/scanner-outcome/action.yml)
- [Generic evaluation adapter](../../actions/evaluation-adapter/action.yml)
- [Ecosystem Baseline Semgrep adapter](../../actions/semgrep-scan/action.yml)
- [Evidence Bundle aggregator](../../actions/aggregate-results/action.yml)
- [Filecoin Security Profile detector](../../actions/detect-filecoin-profile/action.yml)

## Schemas

- [Evaluation Result](../../schemas/evaluation-result.schema.json)
- [Evidence Bundle](../../schemas/evidence-bundle.schema.json)

## Security Profiles

- [Filecoin project profile catalog](../../profiles/filecoin-project-profiles.json)

## Prompts

- [Base reviewer](../../prompts/base-reviewer.md)
- [Filecoin domain](../../prompts/filecoin.md)
- [Generic domain](../../prompts/default.md)
- [Threat-model design](../../prompts/base-threat-modeler.md)

## Consumer Examples

- [Ecosystem Baseline](../../examples/consumer-ecosystem-baseline.yml)
- [Filecoin Security Profile detection](../../examples/consumer-profile-detection.yml)
- [AI review](../../examples/consumer-ai-code-review.yml)
- [Manual AI review](../../examples/consumer-manual-ai-code-review.yml)
- [Security pipeline](../../examples/consumer-security-pipeline.yml)

## Stability

These source files document current pre-v1 behavior. Consumer entrypoints and
their complete execution graph are immutable when selected by a reviewed full
commit; see the [release-integrity contract](release-integrity.md).
