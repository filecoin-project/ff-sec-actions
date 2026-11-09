# evaluation-adapter Specification

## Purpose

Defines the tool-agnostic lifecycle that turns a scanner's outcome, exit code, and raw SARIF into a validated Evaluation Result and a deterministic process exit, independent of how each scanner is installed or invoked.

## Requirements

### Requirement: The adapter normalizes without executing anything
The evaluation adapter SHALL accept evaluation and tool identity with an exact tool version, the tool outcome and exit code, raw SARIF evidence, coverage, and an advisory or blocking policy. It SHALL NOT invoke a package manager, build, scanner, or Consumer Project command. It SHALL request no permission or secret and make no network request.

#### Scenario: Adapter on a fork pull request
- **WHEN** the adapter runs on a fork pull request with raw evidence supplied by the caller
- **THEN** it produces a result without any permission, secret, or network access

### Requirement: Exit codes separate findings from operational failure
The adapter SHALL exit `0` when it produces a result that does not meet the blocking policy, `1` only when findings meet the blocking policy, and `2` only for operational or completion failure.

#### Scenario: Valid SARIF with blocking findings
- **WHEN** a successful tool run produces valid SARIF with findings and `blocking` is true
- **THEN** the result is `complete` and the adapter exits `1`

#### Scenario: Valid SARIF with advisory findings
- **WHEN** a successful tool run produces valid SARIF with findings and `blocking` is false
- **THEN** the result is `complete` and the adapter exits `0`

#### Scenario: Timeout or cancellation
- **WHEN** the tool outcome is timed out or cancelled
- **THEN** the result is `incomplete` and the adapter exits `2`

#### Scenario: Missing or malformed SARIF after success
- **WHEN** the tool reports success but SARIF is missing or malformed
- **THEN** the result is `error` and the adapter exits `2`

#### Scenario: Explicit skip
- **WHEN** the caller declares the evaluation skipped
- **THEN** the result is `skipped` and the adapter exits `0`

### Requirement: Severity is summarized generically
The adapter SHALL summarize SARIF levels as high (`error`), medium (`warning`), info (`note`), or unknown. It SHALL NOT invent scanner-specific severity policy.

#### Scenario: SARIF result without a level
- **WHEN** a SARIF result has no level
- **THEN** it is counted as unknown severity

### Requirement: Raw evidence is hashed into the result
The adapter SHALL record the SHA-256 digest of raw evidence in the normalized result and SHALL emit Evaluation Result `1.1.0`.

#### Scenario: Evidence integrity recorded
- **WHEN** the adapter normalizes a SARIF file
- **THEN** the result's evidence entry carries that file's SHA-256 digest

### Requirement: Scanner leaves conform to the adapter boundary
Each baseline scanner leaf (gitleaks, zizmor, semgrep) SHALL report its operational outcome separately from its findings, run with a pinned exact version and verified archive or image digest, read no secret, and run without the target repository's own scanner configuration unless one is explicitly supplied.

#### Scenario: Zizmor finds issues
- **WHEN** zizmor runs successfully and reports findings
- **THEN** its scanner outcome is `success` and findings are conveyed only through SARIF

#### Scenario: Scanner cannot run
- **WHEN** a scanner leaf cannot execute its scanner or receives an invalid scan scope
- **THEN** its scanner outcome is `failure`, which the adapter normalizes to `error`
