# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: One workflow runs five non-executing evaluations`
- TO: `### Requirement: One workflow runs six non-executing evaluations`

## MODIFIED Requirements

### Requirement: One workflow runs six non-executing evaluations
The Ecosystem Baseline reusable workflow SHALL run six required evaluations: `zizmor-actions` (workflow and action definitions), `gitleaks` (pull-request commit range or full history), `trivy-dependencies` (recursive manifests and lockfiles), `trivy-iac` (recognized infrastructure configuration), `semgrep-baseline` (versioned conservative rules), and `semgrep-foc` (the versioned FOC integrator pack).

#### Scenario: Baseline invoked
- **WHEN** a Consumer Project calls the Ecosystem Baseline workflow at a released SHA
- **THEN** all six evaluations run and each emits an Evaluation Result

### Requirement: One required check carries the profile conclusion
The baseline SHALL aggregate all six results into an Evidence Bundle under profile id `ecosystem-baseline` and SHALL expose one job named `Profile Conclusion` as the branch-protection check. It SHALL upload the bundle and summary as the `ecosystem-baseline-evidence` artifact.

#### Scenario: A scanner job fails
- **WHEN** one evaluation job fails operationally
- **THEN** `Profile Conclusion` still runs, aggregates what it received, and uploads `ecosystem-baseline-evidence`

#### Scenario: FOC result missing
- **WHEN** the `semgrep-foc` Evaluation Result is absent from the aggregated inputs
- **THEN** the bundle reports `semgrep-foc` as missing and `Profile Conclusion` fails under default policy

### Requirement: Static rules are versioned and repository-owned
Static-analysis evaluations SHALL load rules only from their scanner action's immutable commit, never from registry aliases or Consumer Project Semgrep configuration. Baseline rules SHALL cover JavaScript/TypeScript and Rust shell command construction, Go TLS verification disablement, Solidity `tx.origin` authorization, and Dockerfile remote-response piping into a shell. FOC integrator pack rules SHALL come from their own repository-owned file and report under `semgrep-foc`.

#### Scenario: Consumer repository contains a Semgrep config
- **WHEN** the Consumer Project has its own Semgrep configuration file
- **THEN** the baseline ignores it and runs only the versioned baseline and FOC integrator pack rules

#### Scenario: Pack findings are reported separately
- **WHEN** a scan finds both a `tx.origin` authorization and an unchecked `PDPListener` callback
- **THEN** the first appears only in `semgrep-baseline` and the second only in `semgrep-foc`
