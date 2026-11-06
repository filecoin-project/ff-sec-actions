# Spec Delta

## Purpose

Defines how consumer-selected policy turns Evaluation Results and Completion Statuses into a merge-blocking decision, both for each evaluation and for the whole profile, so that a failed or missing evaluation never reads as a pass by default.

## ADDED Requirements

### Requirement: Gate policy never rewrites observations
Each Evaluation Result SHALL carry a merge gate with `mode` (`advisory` or `blocking`), `conclusion` (`pass`, `fail`, or `not-evaluated`), and a required reason. The gate SHALL NOT change the result's completion, coverage, or findings.

#### Scenario: Blocking gate fails
- **WHEN** a blocking evaluation fails its gate
- **THEN** the result's completion, coverage, and findings are unchanged from the observation

### Requirement: Per-evaluation conclusions follow completion and policy
An evaluation's gate SHALL conclude `pass` for a `complete` result with no findings or advisory-only findings, `fail` for blocking findings, `fail` for an `error` or `incomplete` result, and `not-evaluated` for a `skipped` result.

#### Scenario: Tool crash with advisory policy
- **WHEN** an advisory evaluation ends in `error`
- **THEN** its gate concludes `fail`

#### Scenario: Advisory findings
- **WHEN** a `complete` advisory evaluation reports findings
- **THEN** its gate concludes `pass` and the findings remain visible

#### Scenario: Skipped evaluation
- **WHEN** an evaluation is `skipped`
- **THEN** its gate concludes `not-evaluated` with a reason

### Requirement: The profile gate fails on any child failure
The profile Merge Gate SHALL conclude `fail` when any received Evaluation Result's gate concludes `fail`, or when no Evaluation Results were received.

#### Scenario: One child gate fails
- **WHEN** four evaluations pass and one fails its gate
- **THEN** the profile conclusion is `fail` and lists the reason

#### Scenario: No results
- **WHEN** the aggregator receives zero results
- **THEN** the profile conclusion is `fail`

### Requirement: Incomplete coverage fails the profile by default
A consumer SHALL be able to choose `require-complete`, which defaults to `true`. When it is `true`, the profile Merge Gate SHALL conclude `fail` if any required evaluation is missing, `skipped`, `incomplete`, or `error`.

#### Scenario: Default policy with a skipped evaluation
- **WHEN** a required evaluation is skipped and `require-complete` is left at its default
- **THEN** the profile conclusion is `fail` with the reason that complete coverage is required

#### Scenario: Consumer relaxes completeness
- **WHEN** `require-complete` is `false` and a required evaluation is skipped while all others pass
- **THEN** the profile conclusion is `pass` and the bundle still reports the skip

### Requirement: Finding gates are selected per evaluation
A consumer SHALL be able to make each baseline evaluation (actions security, dependencies, secrets, IaC, static analysis) blocking or advisory independently. Each defaults to advisory.

#### Scenario: Only secrets blocking
- **WHEN** a consumer sets secrets to blocking and leaves the rest advisory
- **THEN** only secret findings can fail the profile through findings

### Requirement: Policy and operational failures exit differently
The profile gate SHALL exit `1` for a valid bundle whose conclusion is `fail` and `2` for invalid or ambiguous inputs or an aggregation failure.

#### Scenario: Required check distinguishes failure kinds
- **WHEN** one run fails on blocking findings and another on a malformed result
- **THEN** the first exits `1` and the second exits `2`
