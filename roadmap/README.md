# Implementation Roadmap State

[`state.json`](state.json) is the canonical machine-readable record of task
**order, dependencies, and release gates**. It does not store task status.
Behavior lives in [OpenSpec specs](../openspec/) (`openspec/specs/`) and
in-flight work lives in OpenSpec changes (`openspec/changes/`). Each task links to the change that
delivers it, and the change lifecycle decides the task's status. The
[decision map](../docs/ECOSYSTEM-SECURITY-DECISION-MAP.md) is frozen history.

Each task (schema version 2) contains:

- a stable `id` and topological `order`;
- `phase`, `priority`, and `kind`;
- `change`: the linked OpenSpec change name, or `null` when unclaimed;
- optional `cancelled: true`;
- dependency ids in `blocked_by`;
- the task objective, acceptance criteria, verification, and expected artifacts.

## Derived Status

| Condition | Status |
|---|---|
| `cancelled: true` | `cancelled` |
| `openspec/changes/archive/YYYY-MM-DD-<change>/` exists | `done` |
| `openspec/changes/<change>/` exists | `in_progress` |
| Unclaimed, and a `blocked_by` dependency is not `done` | `blocked` |
| Unclaimed, and every dependency is `done` | `pending` |

Only one task may be `in_progress`. A task cannot be claimed until all its
dependencies are `done`, and a `done` task cannot depend on unfinished work.
A link to a change that does not exist fails validation.

Migration exemption: tasks finished before OpenSpec link to
`bootstrap-security-gate-specs`. Until that change is archived they read
`in_progress`, count as `done` for dependency checks, and do not occupy the
single in-progress slot.

## Read The Queue

Validate the complete state contract:

```bash
bash scripts/roadmap.sh validate
```

Run its isolated derivation, claim, and invariant tests:

```bash
bash scripts/test-roadmap.sh
```

Print the next actionable task as JSON:

```bash
bash scripts/roadmap.sh next
```

List the whole queue with derived status, or only one status:

```bash
bash scripts/roadmap.sh list
bash scripts/roadmap.sh list pending
```

Query order, dependencies, and gates directly with `jq`:

```bash
jq '.tasks[] | select(.priority == "P0" and .change == null)' roadmap/state.json
jq '.release_gates' roadmap/state.json
```

## Claim And Complete A Task

1. Take the task from `bash scripts/roadmap.sh next`.
2. Create its change: `openspec new change "<change-name>"`.
3. Link the task to it. State changes are refused unless write mode is explicit:

   ```bash
   ROADMAP_ALLOW_WRITE=true bash scripts/roadmap.sh claim <TASK-ID> <change-name>
   ```

4. Plan and implement through the change. Settle any open decision ticket the
   task references in `decision_refs` in that change's `design.md`.
5. Archive the change with `openspec archive "<change-name>"`. The task then
   derives `done`.

Commit the state link together with the change, and commit the archive
together with the evidence that satisfies the task's acceptance criteria.

## Ordered Phases

1. Foundation and navigable documentation
2. G0 execution trust and release integrity
3. Evaluation Result, scanner adapters, and evidence aggregation
4. Secretless Ecosystem Baseline
5. Go, Rust/FVM, service, Solidity/FEVM, infrastructure, and monorepo profiles
6. Deterministic Filecoin controls and effectiveness verification
7. Bounded Privileged Analyses
8. Governance, release automation, and generated reference
9. Migration, pilots, public v1, and continuous ecosystem operation
