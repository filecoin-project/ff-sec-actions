# Spec Delta

## Purpose

Defines the normalized, versioned Evaluation Result every evaluation emits, so consumers never infer coverage from an empty finding list or tool success from a green job.

## ADDED Requirements

### Requirement: Results conform to a versioned schema
Every Evaluation Result SHALL validate against the published Evaluation Result JSON Schema at a declared `schema_version` (`1.0.0` or `1.1.0`). It SHALL contain tool identity, target scope, completion, coverage and limitations, finding summary, suppression summary, merge-gate policy, timing, and evidence.

#### Scenario: Missing required field
- **WHEN** a result omits any required top-level field
- **THEN** the result validator rejects it

#### Scenario: Unknown field
- **WHEN** a result contains a field the selected schema version does not define
- **THEN** the result validator rejects it

### Requirement: Completion Status is independent of findings
Each result SHALL report exactly one Completion Status: `complete` (declared scope produced valid evidence), `incomplete` (coverage was reduced), `skipped` (an event, configuration, or missing prerequisite intentionally prevented evaluation), or `error` (a failure prevented a trustworthy result).

#### Scenario: Tool crash
- **WHEN** a scanner exits with an operational failure
- **THEN** the result reports `error` rather than `complete` with zero findings

#### Scenario: Missing optional prerequisite
- **WHEN** an evaluation cannot run because an optional secret or prerequisite is absent
- **THEN** the result reports `skipped`

#### Scenario: Partial coverage
- **WHEN** evaluation starts but cancellation, refusal, truncation, or a limit reduces coverage
- **THEN** the result reports `incomplete` and records the limitation

### Requirement: An unknown finding count is never zero
The finding count SHALL be authoritative only for a `complete` result. When no authoritative count exists, `findings.count` SHALL be `null`. Findings retained by an `incomplete` result SHALL describe only the recorded partial coverage.

#### Scenario: Skipped or errored result
- **WHEN** a result reports `skipped` or `error`
- **THEN** `findings.count` is `null`

#### Scenario: Contradictory state
- **WHEN** a result claims a non-null count together with a completion state that has no finding conclusion
- **THEN** the result validator rejects it

### Requirement: Evidence is content-addressed
Every evidence entry other than `none` SHALL include a path and SHA-256 digest. In schema `1.1.0`, every evidence entry SHALL include a nullable `artifact` field naming the durable artifact that contains the evidence, or `null` when none was published.

#### Scenario: Evidence without digest
- **WHEN** an evidence entry has a path but no SHA-256 digest
- **THEN** the result validator rejects it

#### Scenario: Version-specific artifact field
- **WHEN** a `1.0.0` result includes `evidence[].artifact`, or a `1.1.0` result omits it
- **THEN** the result validator rejects it

### Requirement: Earlier supported versions remain valid
Introducing a new minor schema version SHALL NOT invalidate results that conform to an earlier supported version. The validator SHALL accept every supported version on that version's own terms.

#### Scenario: 1.0.0 result after 1.1.0 is introduced
- **WHEN** a producer that still emits `1.0.0` produces a conforming result
- **THEN** the validator accepts it without requiring fields introduced in `1.1.0`
