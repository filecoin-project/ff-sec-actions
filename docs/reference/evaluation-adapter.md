# Evaluation Adapter

**For:** Platform Maintainers integrating a scanner and Consumer Engineers
debugging result behavior.

**Outcome:** one lifecycle contract from immutable scanner invocation and raw
SARIF to a validated v1 Evaluation Result and deterministic process exit.

**Stability:** pre-v1; Evaluation Result `1.1.0` output introduced in the
consumer alpha. **Owner:** Platform Maintainers; a formal CODEOWNERS path is a
public-v1 prerequisite.

## Inputs And Boundary

[`actions/evaluation-adapter`](../../actions/evaluation-adapter/action.yml) is
tool-agnostic. The calling workflow owns immutable tool invocation and passes:

- stable evaluation and tool identity, including an exact tool version;
- tool outcome and raw exit code;
- raw SARIF evidence;
- evaluated target plus included, excluded, and limited coverage;
- advisory or blocking finding policy.

| Input | Required | Default |
|---|---:|---|
| `evaluation-id` | Yes | — |
| `tool-name` | Yes | — |
| `tool-version` | Yes | — |
| `tool-outcome` | Yes | — |
| `tool-exit-code` | No | Empty |
| `raw-evidence` | No | Empty |
| `evidence-artifact` | No | Empty |
| `remediation-guidance` | No | Safe generic guidance |
| `max-summary-findings` | No | `20` |
| `blocking` | No | `false` |
| `scope-target` | No | `repository` |
| `coverage-included` | No | `[]` |
| `coverage-excluded` | No | `[]` |
| `coverage-limitations` | No | `[]` |
| `evaluation-result-file` | No | Runner temporary directory |
| `summary-file` | No | Runner temporary directory |

Outputs are `completion`, `findings-count`, `merge-conclusion`,
`evaluation-result`, `evidence-artifact`, and `summary`. File outputs are local
to the job; the owning workflow uploads them under names declared in
`security/output-contract.json`.

The adapter does not invoke a package manager, build, scanner, or
Consumer Project command. It validates and normalizes evidence after the tool
step, which keeps tool-specific setup out of the result and policy model.

It requests no permission or secret, makes no network request, and executes no
Consumer Project code. It is event-agnostic and works on pull requests,
including forks, pushes, schedules, and dispatches when the caller can supply
raw evidence. Artifacts use the Consumer Project repository's configured
GitHub Actions retention.

## Lifecycle

| Invocation result | Completion | Adapter exit | Merge conclusion |
|---|---|---:|---|
| Valid SARIF, no findings | `complete` | `0` | `pass` |
| Valid SARIF, advisory findings | `complete` | `0` | `pass` |
| Valid SARIF, blocking findings | `complete` | `1` | `fail` |
| Timed out or cancelled | `incomplete` | `2` | `fail` |
| Tool crash/failure | `error` | `2` | `fail` |
| Missing or malformed SARIF after success | `error` | `2` | `fail` |
| Explicitly skipped | `skipped` | `0` | `not-evaluated` |

Exit `1` is reserved for findings that meet policy. Exit `2` is reserved for
operational or completion failure, so callers never have to infer one from the
other.

Raw evidence is SHA-256-addressed in the normalized result. Generic SARIF
levels are summarized as high (`error`), medium (`warning`), info (`note`), or
unknown; adapters do not invent scanner-specific severity policy.

Before returning its policy or operational exit, the adapter writes a readable
job summary and capped source annotations. The summary maps the stable
evaluation id to scope, coverage, finding locations, rule help, remediation,
gate reason, raw-evidence artifact, and evidence file. Its public outputs also
include the summary path and durable evidence-artifact name. Hashing works with
`sha256sum` or `shasum`, including the Alpine Semgrep runtime.

## Consumption And Compatibility

Call the adapter only from a workflow pinned to the reviewed full repository
commit that owns both the scanner and adapter contract. The current immutable
adapter commit is recorded directly in each normalized `sec-*.yml` workflow;
consumers should pin the parent Ecosystem Baseline workflow rather than copy
that internal reference.

The validator accepts Evaluation Result `1.0.0` and `1.1.0`. Version `1.1.0`
requires nullable artifact identity for every evidence entry. The adapter
emits `1.1.0`; removing an output or changing lifecycle exit semantics requires
migration guidance and a new reviewed release pin.

## Verify

```bash
bash scripts/test-evaluation-adapter.sh
```

The fixture suite covers success, advisory and blocking findings, timeout,
crash, malformed output, and skip.

## Next

- [Evaluation Result contract](evaluation-result.md)
- [Current workflow contracts](current-contracts.md)
- [Consumable output contract](consumable-output.md)
