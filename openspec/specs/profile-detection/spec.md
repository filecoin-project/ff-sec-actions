# profile-detection Specification

## Purpose

Classifies path-scoped components of a Consumer Project into Filecoin Security Profiles from repository signals, recording ambiguity and unsupported components as visible coverage gaps instead of guessing.

## Requirements

### Requirement: Detection never executes project code
The detector SHALL treat repository files, paths, manifests, and configuration as untrusted data. It SHALL read no secret, make no network request, and run no install, build, compiler, repository configuration, or project command. It SHALL work on pull requests, including forks, pushes, schedules, and manual dispatches with only `contents: read`.

#### Scenario: Fork pull request
- **WHEN** the detector runs on a fork pull request with `contents: read`
- **THEN** it completes without any secret, write permission, or network request

### Requirement: Profiles come from a versioned catalog
Profile IDs, labels, descriptions, confidence basis, and planned evaluations SHALL come from the versioned profile catalog. The catalog SHALL define `go-node`, `fvm-actor`, `fevm-contract`, `service`, `infrastructure`, `storage-application`, and `storage-provider-infrastructure`. The detector SHALL fail if its logic references a profile the catalog does not define.

#### Scenario: Unknown profile referenced
- **WHEN** detection logic selects a profile ID absent from the catalog
- **THEN** the detector exits nonzero

### Requirement: Strong signals classify path-scoped components
The detector SHALL classify a component when it finds a strong signal, such as Lotus or Venus nodes, FVM actor SDK or runtime crates, Filecoin-aware Solidity, recognized network service frameworks, infrastructure, storage applications, or storage-provider infrastructure. Each selected profile SHALL carry confidence, path-scoped evidence, and reasons.

#### Scenario: FVM actor crate
- **WHEN** a component depends on an FVM actor SDK or runtime crate
- **THEN** it is classified with the `fvm-actor` profile and the evidence path is recorded

#### Scenario: Monorepo with several components
- **WHEN** a repository contains a Go node and a Solidity contract in different paths
- **THEN** each component is classified separately and profiles are grouped by component path

### Requirement: Weak or unknown signals become coverage gaps
A weak signal shared by several project types, such as `go-state-types`, `fvm_shared`, or a package `start` script, SHALL mark the component `ambiguous` with ambiguity evidence. A component with no recognized signal SHALL be marked `unsupported`. Each ambiguous or unsupported component SHALL count as a coverage gap with remediation and SHALL emit one warning annotation.

#### Scenario: Only a weak signal
- **WHEN** a component's only Filecoin signal is a `go-state-types` dependency
- **THEN** it is marked `ambiguous`, no profile is guessed, and `coverage-gaps-count` includes it

### Requirement: Coverage gaps are separate from completion
A successful run SHALL report `completion=complete` even when coverage gaps exist. An invalid repository path, a missing or invalid catalog, missing `jq`, a filesystem failure, or a rendering error SHALL exit nonzero without emitting a complete result. The detector SHALL have no `skipped` mode.

#### Scenario: Gaps on a successful run
- **WHEN** detection finishes with two unsupported components
- **THEN** `completion` is `complete` and `coverage-gaps-count` is `2`

#### Scenario: Missing catalog
- **WHEN** the profile catalog is missing or invalid
- **THEN** the detector exits nonzero and emits no complete result

### Requirement: Detection outputs are stable and summarized
The detector SHALL output `completion`, `result-file`, `summary`, `profiles-json`, `add-ons-json`, `component-count`, and `coverage-gaps-count`. It SHALL append an escaped component and profile table, and any detected add-ons, to the job summary. By default, result and summary files SHALL be written inside the runner temporary directory, outside the untrusted checkout.

#### Scenario: Default destinations
- **WHEN** a caller leaves result destinations empty
- **THEN** the files are written under the runner temporary directory

#### Scenario: Add-on output when nothing is detected
- **WHEN** detection finds no add-on
- **THEN** `add-ons-json` is an empty JSON array

### Requirement: Detection reports catalog-defined add-ons
The detector SHALL report add-ons defined in the versioned profile catalog, separately from profiles, each with path-scoped evidence. The catalog SHALL define the `foc` add-on. Add-on reporting SHALL NOT change profile classification, coverage gaps, or which evaluations run. The detector SHALL fail if its logic references an add-on the catalog does not define.

#### Scenario: Synapse SDK dependency
- **WHEN** a component's `package.json` depends on `@filoz/synapse-sdk`
- **THEN** the result lists the `foc` add-on with that manifest path as evidence

#### Scenario: Solidity Filecoin Pay or PDP import
- **WHEN** a Solidity file imports a `PDPListener`, `IValidator`, or Filecoin Pay interface
- **THEN** the result lists the `foc` add-on with that file path as evidence

#### Scenario: No FOC signal
- **WHEN** no component contains an FOC signal
- **THEN** the result lists no add-ons and profile classification is unchanged
