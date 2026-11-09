# Spec Delta

## ADDED Requirements

### Requirement: New findings lead the presentation
When raw evidence marks findings as new or existing relative to a base commit, the summary SHALL state the new and existing counts, render new findings before existing ones, and fold existing findings into a count once the render cap is reached. The finding count, gate conclusion, and raw evidence SHALL be unchanged by this classification.

#### Scenario: Pull request adds one finding to a repository with existing findings
- **WHEN** a pull request introduces one finding and the base commit already has 30
- **THEN** the summary reports 1 new and 30 existing, lists the new finding first, and the Evaluation Result still counts 31 findings

#### Scenario: No baseline classification available
- **WHEN** raw evidence carries no new-or-existing marking
- **THEN** the summary renders findings exactly as it did before, with no new or existing counts

### Requirement: Failed classification is visible, never fatal
If a scanner cannot classify findings against the base commit, the evaluation SHALL still complete over its full scope and SHALL record a limitation saying that new-versus-existing classification was unavailable.

#### Scenario: Base commit unavailable
- **WHEN** a pull-request scan cannot read the base commit
- **THEN** the Evaluation Result is `complete` with every finding reported and a limitation naming the missing classification
