# Implementation Roadmap State

[`state.json`](state.json) is the canonical machine-readable implementation
queue. The prose [decision map](../docs/ECOSYSTEM-SECURITY-DECISION-MAP.md)
records why decisions exist; the state file records what to do next, in what
order, and how completion is proven.

Each task contains:

- a stable `id` and topological `order`;
- `phase`, `priority`, `kind`, and `status`;
- dependency ids in `blocked_by`;
- the task objective, acceptance criteria, verification, and expected artifacts;
- optional start and completion timestamps.

## Read The Queue

Validate the complete state contract:

```bash
bash scripts/roadmap.sh validate
```

Run its isolated mutation and dependency tests:

```bash
bash scripts/test-roadmap.sh
```

Print the next actionable task as JSON:

```bash
bash scripts/roadmap.sh next
```

List the whole queue or one status:

```bash
bash scripts/roadmap.sh list
bash scripts/roadmap.sh list pending
```

Query directly with `jq`:

```bash
jq '.tasks[] | select(.priority == "P0" and .status == "pending")' roadmap/state.json
jq '.release_gates' roadmap/state.json
```

## Update State Deliberately

State changes are refused unless write mode is explicit:

```bash
ROADMAP_ALLOW_WRITE=true bash scripts/roadmap.sh set-status G0-01 in_progress
ROADMAP_ALLOW_WRITE=true bash scripts/roadmap.sh set-status G0-01 done
```

Only one task may be `in_progress`. A task cannot be claimed until all its
dependencies are `done`, and a completed task cannot depend on incomplete work.
Commit state changes together with the evidence that satisfies the task's
acceptance criteria.

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
