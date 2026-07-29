# Evidence Bundle And Profile Conclusion

**For:** Consumer Engineers interpreting the pipeline and Platform Maintainers
building Security Profiles.

**Outcome:** one authoritative JSON bundle, readable summary, and required
check over all expected Evaluation Results.

The [v1 Evidence Bundle schema](../../schemas/evidence-bundle.schema.json)
records the selected profile/version, repository scope, required evaluation
ids, received results, missing evaluations, completion summary, observed
findings and suppressions, and the final merge conclusion.

## Aggregation Rules

[`actions/aggregate-results`](../../actions/aggregate-results/action.yml):

1. validates every input against Evaluation Result v1;
2. rejects duplicate evaluation ids as ambiguous evidence;
3. reports missing, incomplete, skipped, and error results separately;
4. sums observed findings and suppressions without calling a partial sum
   authoritative;
5. fails if any child merge gate fails;
6. fails incomplete profile coverage when `require-complete` is true;
7. emits `evidence-bundle.json` and a Markdown job summary before returning the
   profile conclusion.

The summary maps every evaluation to its Completion Status, findings count,
Merge Gate conclusion and reason, evaluated scope, durable artifact name, and
evidence path. Consumers should not have to infer that mapping from job names
or adapter exit codes.

The aggregate exits `1` for a valid bundle whose profile Merge Gate fails and
`2` for invalid/ambiguous inputs or aggregation failure. A required GitHub job
therefore distinguishes policy failure from operational failure while retaining
the bundle as evidence.

## Current Vertical Pipeline

The first vertical pipeline aggregates the dependency Evaluation Result. It is
deliberately narrow: it proves the artifact handoff, validation, bundle,
summary, and stable conclusion before the Ecosystem Baseline composes multiple
evaluations.

## Verify

```bash
bash scripts/test-aggregate-results.sh
```

Fixtures cover clean results, blocking findings, skipped evaluation, error,
suppression totals, missing coverage, and duplicate ids.

## Next

- [Evaluation Result](evaluation-result.md)
- [Evaluation adapter](evaluation-adapter.md)
- [Consumable output contract](consumable-output.md)
