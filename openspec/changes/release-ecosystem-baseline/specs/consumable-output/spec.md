## ADDED Requirements

### Requirement: Suppressed findings are listed in the summary
When an evaluation counts in-source suppressions, its job summary SHALL state the suppression count and source and SHALL list each suppressed result with rule, path, and line, under the same render cap as findings. Suppressed results SHALL NOT produce source annotations.

#### Scenario: Pull request adds a nosemgrep comment
- **WHEN** a Consumer Project adds `// nosemgrep` to a line that Semgrep reports
- **THEN** the summary shows `Suppressed in source: 1 (semgrep-inline)` with that rule, path, and line, and no annotation is emitted for it

### Requirement: Coverage exclusions and limitations are shown
Each evaluation's job summary SHALL list its coverage exclusions and limitations as recorded in the Evaluation Result, including any computed from the scanned repository.

#### Scenario: Files excluded by a Consumer Project ignore file
- **WHEN** an evaluation records that a Consumer Project `.semgrepignore` excluded four files
- **THEN** that exclusion, its count, and its source appear in the evaluation's job summary
