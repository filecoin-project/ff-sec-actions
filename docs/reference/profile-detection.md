# Filecoin Security Profile Detection

**Stability:** pre-v1 composite-action contract

**Introduced:** detector and result schema `0.1.0`

**Owner:** Filecoin ecosystem security platform maintainers; a formal
`CODEOWNERS` path remains required before public v1.

The detector classifies path-scoped project components and records uncertainty
without executing Consumer Project code.

## Authority And Prerequisites

| Concern | Contract |
|---|---|
| Caller permission | `contents: read` for checkout |
| Secrets | None read or accepted |
| Network | None from the detector; GitHub downloads the pinned action and optional artifact action |
| Consumer code execution | Forbidden; no install, build, compiler, repository configuration, or project command |
| Runner and cache | GitHub-hosted runner; no cache |
| Required runner tools | Bash, `find`, `grep`, and `jq`, all present on GitHub-hosted Ubuntu runners |

Checkout credentials must not persist. Repository files, paths, manifests, and
configuration are treated as untrusted data.

## Immutable Consumption

Copy the complete
[`consumer-profile-detection.yml`](../../examples/consumer-profile-detection.yml)
example. It selects the reviewed detector implementation at
`d4bd966bc0b5e29d0d23dc51112bcf1e67398957`, pins every external action, grants
read-only contents access, and uploads the result and summary.

The Control Repository remains pre-v1. Do not replace the full commit with a
moving branch or an unpublished `v1` tag.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `repository-path` | `.` | Checked-out repository path treated as untrusted data |
| `result-file` | Runner temporary directory | Machine-readable result destination |
| `summary-file` | Runner temporary directory | Readable component/profile table destination |

Empty result destinations resolve inside `runner.temp`, outside the untrusted
checkout. Callers that override them own the safety of those paths.

## Outputs

| Output | Meaning |
|---|---|
| `completion` | `complete` after discovery, classification, result rendering, and summary rendering finish |
| `result-file` | Path to the complete JSON result |
| `summary` | Path to the Markdown component/profile table |
| `profiles-json` | Compact array of selected profile IDs and path scopes |
| `component-count` | Number of recognized components, including ambiguous and unsupported components |
| `coverage-gaps-count` | Number of ambiguous or unsupported components requiring review |

The action appends the escaped table to the GitHub job summary and emits one
warning annotation per coverage gap. Profile labels come from the versioned
catalog; the detector fails if implementation references an unknown profile.

## Completion And Failure Behavior

A successful invocation emits `completion=complete`, even when coverage gaps
exist. Gaps describe classification coverage and must not be confused with an
operationally incomplete run. Consumers decide whether a nonzero
`coverage-gaps-count` is advisory or requires manual review before merge.

An invalid repository path, missing/invalid catalog, missing `jq`, filesystem
failure, or rendering error exits nonzero. The action does not emit a clean or
complete result after such an operational failure. It has no `skipped` mode and
does not convert ambiguity into success without a visible gap.

## Result Model

The version `1` JSON document contains:

- detector name/version, target, and completion;
- components with `classified`, `ambiguous`, or `unsupported` status;
- selected profiles with confidence, path-scoped evidence, and reasons;
- ambiguity evidence for weak signals shared by several project types;
- selected profiles grouped by component path; and
- included paths, coverage gaps, remediation, and limitations.

Strong signals currently cover Lotus/Venus nodes, FVM actor SDK/runtime crates,
Filecoin-aware Solidity, recognized network service frameworks, infrastructure,
storage applications, and storage-provider infrastructure. Weak signals such
as `go-state-types`, `fvm_shared`, or a package `start` script produce ambiguity
instead of a guessed profile.

The catalog at
[`profiles/filecoin-project-profiles.json`](../../profiles/filecoin-project-profiles.json)
is the source of truth for profile IDs, labels, descriptions, confidence basis,
and planned evaluations. Detection patterns remain implementation logic covered
by planted fixtures; narrative documentation does not duplicate them.

## Events, Forks, And Artifacts

The action supports pull requests, fork pull requests, pushes, schedules, and
manual dispatches. Forks are safe because detection requires no secret, write
permission, external request, or project execution.

The action creates runner-local JSON and Markdown files. The executable example
uploads both as `filecoin-profile-detection`. Artifact retention follows the
Consumer Project repository's GitHub Actions retention setting unless the
caller explicitly supplies `retention-days` to its upload step.

## Compatibility And Deprecation

The output names, result schema, profile IDs, and catalog version are pre-v1
contracts. Removing or renaming them requires migration guidance and an
immutable example-pin advance. There are no deprecated inputs or profile IDs in
`0.1.0`. Additive detection signals still require fixtures because a new match
can change a component from unsupported or ambiguous to classified.

## Maintainer Verification

```bash
bash scripts/test-detect-filecoin-profile.sh
bash scripts/check-output-contract.sh
bash scripts/check-execution-trust.sh
bash scripts/check-release-graph.sh
```

## Next

- [Choose a Security Profile](../consumers/choose-a-profile.md)
- [Consumable output contract](consumable-output.md)
- [Execution trust tiers](execution-trust.md)
