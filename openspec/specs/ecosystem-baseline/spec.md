# ecosystem-baseline Specification

## Purpose

Provides the secretless, non-executing set of security evaluations that any Consumer Project can adopt with one reusable workflow and one required check, safely on every pull request including forks.

## Requirements

### Requirement: One workflow runs six non-executing evaluations
The Ecosystem Baseline reusable workflow SHALL run six required evaluations: `zizmor-actions` (workflow and action definitions), `gitleaks` (pull-request commit range or full history), `trivy-dependencies` (recursive manifests and lockfiles), `trivy-iac` (recognized infrastructure configuration), `semgrep-baseline` (versioned conservative rules), and `semgrep-foc` (the versioned FOC integrator pack).

#### Scenario: Baseline invoked
- **WHEN** a Consumer Project calls the Ecosystem Baseline workflow at a released SHA
- **THEN** all six evaluations run and each emits an Evaluation Result

### Requirement: The baseline runs without authority or project execution
Every baseline job SHALL run without repository or organization secrets, OIDC, write authority, shared caches, self-hosted runners, package installation, builds, tests, or project commands, so it is safe on ordinary fork `pull_request` events.

#### Scenario: Fork pull request
- **WHEN** the baseline runs on a fork pull request
- **THEN** every evaluation completes with read-only authority and no project code runs

### Requirement: One required check carries the profile conclusion
The baseline SHALL aggregate all six results into an Evidence Bundle under profile id `ecosystem-baseline` and SHALL expose one job named `Profile Conclusion` as the branch-protection check. It SHALL upload the bundle and summary as the `ecosystem-baseline-evidence` artifact.

#### Scenario: A scanner job fails
- **WHEN** one evaluation job fails operationally
- **THEN** `Profile Conclusion` still runs, aggregates what it received, and uploads `ecosystem-baseline-evidence`

#### Scenario: FOC result missing
- **WHEN** the `semgrep-foc` Evaluation Result is absent from the aggregated inputs
- **THEN** the bundle reports `semgrep-foc` as missing and `Profile Conclusion` fails under default policy

### Requirement: Default policy is advisory findings with required completion
By default, every finding gate SHALL be advisory and `require-complete` SHALL be `true`, so a missing or broken scanner fails the profile while findings stay visible but do not block.

#### Scenario: Default adoption with a broken scanner
- **WHEN** a Consumer Project adopts the baseline with defaults and one scanner errors
- **THEN** `Profile Conclusion` fails

#### Scenario: Default adoption with findings
- **WHEN** a Consumer Project adopts the baseline with defaults and evaluations complete with findings
- **THEN** `Profile Conclusion` passes and the findings appear in the summary and bundle

### Requirement: Static rules are versioned and repository-owned
Static-analysis evaluations SHALL load rules only from their scanner action's immutable commit, never from registry aliases or Consumer Project Semgrep configuration. Baseline rules SHALL cover JavaScript/TypeScript and Rust shell command construction, Go TLS verification disablement, Solidity `tx.origin` authorization, and Dockerfile remote-response piping into a shell. FOC integrator pack rules SHALL come from their own repository-owned file and report under `semgrep-foc`.

#### Scenario: Consumer repository contains a Semgrep config
- **WHEN** the Consumer Project has its own Semgrep configuration file
- **THEN** the baseline ignores it and runs only the versioned baseline and FOC integrator pack rules

#### Scenario: Pack findings are reported separately
- **WHEN** a scan finds both a `tx.origin` authorization and an unchecked `PDPListener` callback
- **THEN** the first appears only in `semgrep-baseline` and the second only in `semgrep-foc`

### Requirement: Limitations are explicit
Each baseline result SHALL record coverage it cannot provide, including installed or build-generated dependencies and unsupported source patterns, as limitations. A clean result SHALL mean only that the declared checks completed over the reported scope.

#### Scenario: Build-generated dependencies
- **WHEN** a project's dependency set depends on a build step
- **THEN** the dependency result lists that as a limitation rather than claiming full coverage
