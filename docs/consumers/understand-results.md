# Understand Evaluation Results

**For:** a Consumer Engineer or Rollout Operator interpreting a workflow run.

**Outcome:** a decision that does not confuse tool execution, findings, and
merge policy.

## Three Separate Questions

1. **Did the evaluation complete its declared scope?**
2. **What findings and coverage limitations did it report?**
3. **What does this project's Merge Gate do with that evidence?**

These questions are intentionally independent. A tool failure or skipped job is
not equivalent to zero findings.

## Current Behavior

The Ecosystem Baseline's five scanner adapters and the AI review action emit
the pre-v1 [Evaluation Result contract](../reference/evaluation-result.md):

- scanner outputs may appear in job logs, SARIF, or artifacts;
- supported scanner gates keep advisory findings green by policy while
  malformed SARIF and tool failure fail independently;
- scanner event/configuration skips are represented as `skipped`;
- AI refusal and large-diff or response truncation are `incomplete`;
- a missing Anthropic secret is `skipped`, never zero findings;
- the Ecosystem Baseline aggregates its five required results into one Evidence
  Bundle and one authoritative `Profile Conclusion` check.

For the Ecosystem Baseline, start with `Profile Conclusion` and the
`ecosystem-baseline-evidence` artifact. Inspect an individual Evaluation Result
and its raw evidence when the bundle reports findings or incomplete coverage.

The legacy full security pipeline has not migrated every scanner to the
aggregate contract. In that pipeline, inspect each scanner's result, raw
artifact, and job conclusion independently; do not infer suite-wide completion
from a green parent workflow.

## Target Completion Status

| Status | Meaning | Suitable for a strict Merge Gate? |
|---|---|---|
| `complete` | Declared scope ran and produced usable evidence | Yes, subject to findings |
| `incomplete` | Some declared coverage was unavailable or truncated | Usually block or require review |
| `skipped` | Policy or event rules intentionally excluded the evaluation | Only if the skip is expected |
| `error` | The tool or platform failed operationally | No |

Finding severity remains separate: `critical`, `high`, `medium`, `low`, and
`info`.

## Rollout Policy

1. Observe results without blocking.
2. Confirm that enabled evaluations complete reliably.
3. Triage findings and document narrowly scoped suppressions.
4. Gate only deterministic, high-confidence results.
5. Decide explicitly how incomplete, skipped, and error statuses affect merge.
6. Revisit thresholds after profile or tool upgrades.

## Next

- [Review permissions and secrets](permissions-and-secrets.md)
- [Return to the quickstart](quickstart.md)
- [See the target evidence interface](../ECOSYSTEM-SECURITY-DECISION-MAP.md#evidence-interface-give-humans-and-automation-one-result-surface)
