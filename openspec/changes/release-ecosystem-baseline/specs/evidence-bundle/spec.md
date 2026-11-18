## ADDED Requirements

### Requirement: The profile summary surfaces coverage gaps and suppressions
The aggregator's Markdown summary SHALL list, for each received evaluation, its coverage exclusions, its limitations, and its suppression count, showing an unknown count as unknown rather than zero. Evaluations with none SHALL be omitted from that section.

#### Scenario: One evaluation has gaps
- **WHEN** `semgrep-baseline` records one exclusion and two suppressions and `gitleaks` records an unknown suppression count
- **THEN** the Profile Conclusion summary lists the exclusion and `2` under `semgrep-baseline`, and `unknown` under `gitleaks`

#### Scenario: No gaps anywhere
- **WHEN** every received result has no exclusions, no limitations, and a zero suppression count
- **THEN** the summary states that no evaluation reported coverage gaps or suppressions
