# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Detection outputs are stable and summarized
The detector SHALL output `completion`, `result-file`, `summary`, `profiles-json`, `add-ons-json`, `component-count`, and `coverage-gaps-count`. It SHALL append an escaped component and profile table, and any detected add-ons, to the job summary. By default, result and summary files SHALL be written inside the runner temporary directory, outside the untrusted checkout.

#### Scenario: Default destinations
- **WHEN** a caller leaves result destinations empty
- **THEN** the files are written under the runner temporary directory

#### Scenario: Add-on output when nothing is detected
- **WHEN** detection finds no add-on
- **THEN** `add-ons-json` is an empty JSON array
