# Evaluation Result Contract

The pre-v1 [JSON Schema](../../schemas/evaluation-result.schema.json) defines the
machine-readable result emitted by the scanner outcome adapter and AI review
action. It exists so consumers never have to infer coverage from an empty
finding list or a green advisory job.

## Completion Is Independent From Findings

| Completion | Meaning | Findings interpretation |
|---|---|---|
| `complete` | The declared evaluation scope produced valid evidence | The finding count is authoritative for that scope |
| `incomplete` | Evaluation began, but cancellation or a limit reduced coverage | Findings are observations from partial coverage only |
| `skipped` | An event, configuration, or unavailable prerequisite intentionally prevented evaluation | No finding conclusion is available |
| `error` | A tool, provider, or result-validation failure prevented a trustworthy result | No finding conclusion is available |

`findings.count: null` means the action has no authoritative count. It is not
equivalent to zero. Finding severity and the action's gate conclusion remain
separate from completion.

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

The schema version is `0.1.0`. Ticket `EVAL-01` will finalize the v1 fields and
stability rules before the first ecosystem-wide release.

## Validate a Result

```bash
bash scripts/check-evaluation-result.sh /path/to/evaluation-result.json
```

The repository contract suite covers all four completion states for both
scanner and AI result kinds, including missing secrets, model refusal,
truncation, event skips, and tool outages.
