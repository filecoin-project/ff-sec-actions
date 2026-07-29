# Evaluation Result Contract

The stable v1 [JSON Schema](../../schemas/evaluation-result.schema.json) defines
the machine-readable result emitted by every evaluation adapter. It exists so
consumers never have to infer coverage from an empty finding list, infer tool
success from a green advisory job, or confuse observed findings with policy.

## Completion Is Independent From Findings

| Completion | Meaning | Findings interpretation |
|---|---|---|
| `complete` | The declared evaluation scope produced valid evidence | The finding count is authoritative for that scope |
| `incomplete` | Evaluation began, but cancellation or a limit reduced coverage | Findings are observations from partial coverage only |
| `skipped` | An event, configuration, or unavailable prerequisite intentionally prevented evaluation | No finding conclusion is available |
| `error` | A tool, provider, or result-validation failure prevented a trustworthy result | No finding conclusion is available |

`findings.count: null` means the action has no authoritative count. It is not
equivalent to zero. An incomplete evaluation may retain observed findings, but
they describe only the recorded partial coverage.

## Findings And Merge Policy Are Independent

`merge_gate.mode` is `advisory` or `blocking`. Its `conclusion` is `pass`,
`fail`, or `not-evaluated`, with a required reason. The gate is a policy result;
it does not rewrite `completion`, `coverage`, or `findings`.

| Observation | Completion | Findings | Merge gate |
|---|---|---:|---|
| Valid evidence, no findings | `complete` | `0` | `pass` |
| Valid evidence, advisory findings | `complete` | `>0` | `pass` |
| Valid evidence, blocking findings | `complete` | `>0` | `fail` |
| Tool crash | `error` | `null` | `fail` |
| Missing optional prerequisite | `skipped` | `null` | `not-evaluated` |
| Partial evidence with a blocking observed finding | `incomplete` | `>0` | `fail` |

The future profile aggregator decides whether `incomplete`, `skipped`, or
unsupported coverage is acceptable for a named Security Profile. Individual
results never claim profile completeness.

## Required Fields

Version `1.0.0` requires tool identity, target scope, completion, coverage and
limitations, finding summary, suppression summary, merge policy, timing, and
content-addressed evidence. Evidence other than `none` requires a path and
SHA-256 digest. Unknown fields are rejected so misspellings and incompatible
producer changes cannot silently pass validation.

## Current Emitters

- [`scanner-outcome`](../../actions/scanner-outcome/action.yml) validates SARIF,
  records evidence integrity, distinguishes tool failure from findings, and
  maps event/configuration skips explicitly.
- [`ai-code-review`](../../actions/ai-code-review/action.yml) emits `skipped` for
  a missing provider secret, `incomplete` for refusal or truncation, and `error`
  for provider or structured-output failure.

Both actions expose an `evaluation-result` output containing the runner-local
JSON path. The AI action also exposes `completion-status`; the scanner adapter
retains its `completion` output for compatibility.

## Evolution And Unknown Fields

- A patch version clarifies documentation or validation without changing the
  accepted JSON shape.
- A minor version may add an explicitly optional field. Producers do not emit
  it to a consumer that has selected an older contract.
- A major version may change required fields or semantics and requires a
  separately selected adapter/profile version.
- Validators reject unknown fields. Consumers must select a supported schema
  version explicitly and must not discard fields before validation.
- Producers never reinterpret an existing enum value; they add a versioned
  value or advance the schema instead.

## Validate a Result

```bash
bash scripts/check-evaluation-result.sh /path/to/evaluation-result.json
```

The repository includes committed valid and invalid fixtures under
`test/fixtures/evaluation-result/`. The contract suite covers all four
completion states for scanner and AI result kinds, unknown fields,
contradictory states, invalid evidence, missing secrets, refusal, truncation,
event skips, and tool outages.
