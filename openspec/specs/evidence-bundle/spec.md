# evidence-bundle Specification

## Purpose

Aggregates every expected Evaluation Result for a selected Security Profile into one authoritative, schema-validated Evidence Bundle that records coverage, completion, findings, and suppressions without calling partial evidence authoritative.

## Requirements

### Requirement: The bundle validates every input
The aggregator SHALL validate every input against Evaluation Result v1 before aggregation and SHALL treat an invalid input as an aggregation failure.

#### Scenario: Malformed input result
- **WHEN** one input fails Evaluation Result validation
- **THEN** aggregation fails operationally and exits `2`

### Requirement: Duplicate evaluation ids are ambiguous evidence
The aggregator SHALL reject inputs that share an evaluation id.

#### Scenario: Two results with the same id
- **WHEN** two inputs report the same evaluation id
- **THEN** aggregation fails operationally and exits `2`

### Requirement: Missing and non-complete evaluations are reported separately
The bundle SHALL record the selected profile and version, repository scope, required evaluation ids, received results, and missing evaluations. It SHALL report `incomplete`, `skipped`, `error`, and missing evaluations as distinct categories in its completion summary.

#### Scenario: Required evaluation absent
- **WHEN** a required evaluation id has no input result
- **THEN** the bundle lists it as missing rather than omitting it

#### Scenario: Skipped evaluation
- **WHEN** one input result is `skipped`
- **THEN** the completion summary counts it as skipped, not complete

### Requirement: Partial sums are never authoritative
The bundle SHALL sum observed findings and suppressions across results. Neither total SHALL be authoritative when any required evaluation is missing or no result was received. The findings total SHALL also be non-authoritative when any received result is not `complete` or has an unknown count.

#### Scenario: Required evaluation missing
- **WHEN** one of two required evaluations has no result and the other is `complete` with zero findings
- **THEN** the bundle marks both the findings and suppression totals non-authoritative

#### Scenario: Skipped evaluation
- **WHEN** one received result is `skipped`
- **THEN** the bundle reports the observed findings total and marks it non-authoritative

### Requirement: The bundle is emitted before the conclusion
The aggregator SHALL write `evidence-bundle.json` conforming to the Evidence Bundle v1 schema and a Markdown job summary before it returns the profile conclusion, so the bundle survives a failing gate.

#### Scenario: Profile gate fails
- **WHEN** the profile Merge Gate fails
- **THEN** `evidence-bundle.json` and the summary already exist when the aggregator exits
