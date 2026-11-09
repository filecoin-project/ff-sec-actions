# consumable-output Specification

## Purpose

Guarantees that every reusable evaluation workflow and composite action tells a Consumer Engineer what ran, what it found and where, how to remediate it, why policy passed or failed, and where durable evidence lives.

## Requirements

### Requirement: Every interface is declared in the output inventory
Every reusable workflow and composite action SHALL be declared in the machine-readable output contract inventory. It SHALL either use the shared evaluation adapter or name its provider-native surface and remediation source.

#### Scenario: Undeclared workflow
- **WHEN** a reusable workflow or composite action is added without an output-contract entry
- **THEN** the output-contract check fails

### Requirement: Each evaluation exposes the required surfaces
Each evaluation SHALL produce a job summary (tool and version, Completion Status, finding count and severity, gate reason, scope, coverage, evidence artifact), capped source annotations, remediation guidance, an Evaluation Result, and a predictably named durable raw-evidence artifact.

#### Scenario: Summary on a failing gate
- **WHEN** an evaluation fails its blocking gate
- **THEN** the job summary and annotations exist before the job exits

### Requirement: Finding presentation is bounded and escaped
The adapter SHALL render at most 20 findings by default, each with severity, rule, path, line, message, and available rule help. Annotations SHALL be escaped. The complete result SHALL remain in the raw-evidence artifact.

#### Scenario: Large finding set
- **WHEN** a scanner reports 500 findings
- **THEN** at most 20 are rendered and all 500 remain in the raw-evidence artifact

### Requirement: Secret values are always redacted
Secret-detection output SHALL be fully redacted before the adapter receives it. Secret remediation SHALL begin with revocation or rotation, followed by history removal and access-log review. Suppression SHALL be described as appropriate only for a verified false positive.

#### Scenario: Leaked credential found
- **WHEN** secret detection finds a credential
- **THEN** no summary, annotation, or result contains the credential value

### Requirement: Rendering requires no extra authority
Producing summaries, annotations, and results SHALL require no additional permission, secret, network request, or project code execution, and SHALL behave the same on pull requests, pushes, schedules, and manual runs.

#### Scenario: Fork pull request
- **WHEN** an evaluation runs on a fork pull request
- **THEN** its summary and annotations are produced with `contents: read` only

### Requirement: Declared interfaces cannot silently change
A reusable evaluation workflow SHALL keep exposing the stable evaluation id, raw-evidence artifact, normalized-result artifact, remediation guidance, tool-outcome mapping, and blocking policy its inventory entry declares. Removing or renaming any of them SHALL fail the output-contract check until the inventory is updated.

#### Scenario: Evaluation id renamed in a workflow
- **WHEN** a workflow stops exposing the evaluation id its inventory entry declares
- **THEN** the output-contract check fails

#### Scenario: Raw-evidence artifact renamed
- **WHEN** a workflow publishes raw evidence under a name other than the declared artifact
- **THEN** the output-contract check fails

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
