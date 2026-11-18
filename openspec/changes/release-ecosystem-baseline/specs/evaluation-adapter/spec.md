## ADDED Requirements

### Requirement: In-source suppressions are counted separately from findings
When the caller declares a suppression source, the adapter SHALL treat each SARIF result with a non-empty `suppressions` array as a suppression, not a finding. It SHALL leave that result out of the finding count, highest severity, gate, and annotations. It SHALL record the number of such results and the declared source in the Evaluation Result's `suppressions` field. Raw evidence SHALL keep every result unchanged.

#### Scenario: One finding suppressed in source
- **WHEN** a successful Semgrep run produces SARIF with three results, one carrying `suppressions: [{kind: "inSource"}]`, and the caller declares source `semgrep-inline`
- **THEN** the Evaluation Result reports two findings and `suppressions: {count: 1, sources: ["semgrep-inline"]}`, and the raw evidence still holds all three results

#### Scenario: Suppressed result cannot fail a blocking gate
- **WHEN** `blocking` is true and every SARIF result carries an in-source suppression
- **THEN** the result is `complete` with zero findings, the gate passes, and the adapter exits `0`

### Requirement: Undeclared suppression visibility stays unknown
When the caller declares no suppression source, the adapter SHALL record `suppressions.count` as `null` and SHALL count every SARIF result as a finding, so a scanner that drops suppressed results before writing SARIF never reports a false zero.

#### Scenario: Scanner that removes suppressions itself
- **WHEN** the caller declares no suppression source and SARIF contains two results
- **THEN** the Evaluation Result reports two findings and `suppressions.count` is `null`

### Requirement: Computed coverage gaps are appended and mark coverage partial
The adapter SHALL accept coverage exclusions and limitations computed from the scanned repository in addition to the caller's declared ones. It SHALL append them to the Evaluation Result's coverage and, when any computed entry exists on a complete result, SHALL set coverage status to `partial` without changing Completion Status. Computed inputs SHALL be validated as JSON string arrays like declared coverage.

#### Scenario: Scanner skipped ignored files
- **WHEN** a successful scan supplies one computed exclusion
- **THEN** the result is `complete`, its coverage status is `partial`, and its excluded list ends with that exclusion

#### Scenario: Malformed computed coverage
- **WHEN** computed coverage is not a JSON array of strings
- **THEN** the adapter fails operationally and exits `2`
