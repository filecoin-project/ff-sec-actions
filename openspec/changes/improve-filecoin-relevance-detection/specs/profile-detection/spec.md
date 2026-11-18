## MODIFIED Requirements

### Requirement: Strong signals classify path-scoped components
The detector SHALL classify a component when it finds a strong signal, such as Lotus or Venus nodes, FVM actor SDK or runtime crates, Filecoin-aware Solidity, recognized network service frameworks, infrastructure, storage applications, or storage-provider infrastructure. Each selected profile SHALL carry confidence, path-scoped evidence, and reasons.

#### Scenario: FVM actor crate
- **WHEN** a component depends on an FVM actor SDK or runtime crate
- **THEN** it is classified with the `fvm-actor` profile and the evidence path is recorded

#### Scenario: Monorepo with several components
- **WHEN** a repository contains a Go node and a Solidity contract in different paths
- **THEN** each component is classified separately and profiles are grouped by component path

#### Scenario: Solidity that integrates FOC
- **WHEN** a Solidity component imports a PDP verifier, PDP listener, Filecoin Pay, or `@filoz/` interface
- **THEN** it is classified `fevm-contract` with that file as evidence

#### Scenario: Solidity deployed to a Filecoin network
- **WHEN** a component's `hardhat.config.*` or `foundry.toml` declares chain ID `314` or `314159`, or an RPC URL whose host is a cataloged Filecoin RPC host
- **THEN** its Solidity component is classified `fevm-contract` at `medium` confidence with that configuration file as evidence

#### Scenario: Storage application SDK
- **WHEN** a `package.json` declares `@filoz/synapse-sdk`, a `@storacha/` package, or `filecoin-pin` as a dependency
- **THEN** the component is classified `storage-application`

### Requirement: Detection outputs are stable and summarized
The detector SHALL output `completion`, `result-file`, `summary`, `profiles-json`, `add-ons-json`, `filecoin-relevance`, `component-count`, and `coverage-gaps-count`. It SHALL append an escaped component and profile table, the repository's Filecoin relevance, and any detected add-ons, to the job summary. By default, result and summary files SHALL be written inside the runner temporary directory, outside the untrusted checkout.

#### Scenario: Default destinations
- **WHEN** a caller leaves result destinations empty
- **THEN** the files are written under the runner temporary directory

#### Scenario: Add-on output when nothing is detected
- **WHEN** detection finds no add-on
- **THEN** `add-ons-json` is an empty JSON array

#### Scenario: Relevance output
- **WHEN** detection finds any Filecoin relevance signal in any component
- **THEN** `filecoin-relevance` is `relevant` and the summary states it with the number of relevant components

## ADDED Requirements

### Requirement: Filecoin relevance is reported separately from profiles
Each component and the repository SHALL report `filecoin_relevance` as `relevant` or `not-detected`. The `relevant` status SHALL carry path-scoped evidence naming the matched signal. A component SHALL be relevant when any cataloged relevance signal matches, whether or not a profile is selected. A relevant component without a profile SHALL remain a coverage gap whose reason says it is Filecoin-relevant.

#### Scenario: Filecoin dependency without a profile
- **WHEN** a Go component requires `github.com/filecoin-project/go-f3` and matches no profile rule
- **THEN** it is `relevant` with that `go.mod` as evidence, stays a coverage gap, and the gap reason names it as Filecoin-relevant

#### Scenario: No Filecoin signal
- **WHEN** a repository contains only a generic Express service and a Dockerfile
- **THEN** the repository's `filecoin_relevance` is `not-detected`

### Requirement: Relevance signals are cataloged and anchored to declarations
Relevance signals SHALL come from the versioned profile catalog, grouped by kind: Go module prefix, Cargo crate, npm package, Solidity import, FEVM chain ID, and Filecoin RPC host. Each kind SHALL match only its declaring syntax (module paths, dependency keys and package names, import paths, or network configuration values), never a substring elsewhere in the file.

#### Scenario: Name only in a comment or string
- **WHEN** a `go.mod` mentions `github.com/filecoin-project/lotus` only in a comment, or a `package.json` mentions `@filoz/synapse-sdk` only in its description
- **THEN** no relevance or profile is reported from that file

#### Scenario: Catalog references
- **WHEN** detection logic references a relevance signal kind the catalog does not define
- **THEN** the detector exits nonzero

### Requirement: Storage-provider terms match only whole tokens outside CI definitions
Storage-provider infrastructure SHALL be detected only from whole-token matches of cataloged storage-provider binaries and API variables in Terraform, Dockerfile, Kubernetes, Compose, or systemd configuration. Files under `.github/` SHALL NOT produce a storage-provider signal.

#### Scenario: Ordinary words in CI YAML
- **WHEN** a repository's only YAML is a GitHub workflow containing "curious" and "boost"
- **THEN** no `storage-provider-infrastructure` profile and no Filecoin relevance are reported

#### Scenario: Proofs cache variable in a workflow
- **WHEN** `FIL_PROOFS_PARAMETER_CACHE` appears only under `.github/workflows/`
- **THEN** no `storage-provider-infrastructure` profile is reported for that path

#### Scenario: Storage-provider deployment
- **WHEN** a Compose file runs `curio` with `FULLNODE_API_INFO`
- **THEN** the component is classified `storage-provider-infrastructure`

### Requirement: Detection accuracy is measured against a pinned corpus
The Control Repository SHALL keep a detection corpus record listing Filecoin repositories and non-Filecoin negative controls at full commit SHAs, each with expected relevance and observed detector output. CI SHALL fail when any entry lacks observed output, any Filecoin repository is observed `not-detected`, any negative control is observed `relevant`, or the recorded detector version differs from the current one.

#### Scenario: Negative control matches
- **WHEN** a detector change makes a recorded negative control report `relevant`, and the record is refreshed
- **THEN** the detection test fails

#### Scenario: Stale record
- **WHEN** the detector version changes without refreshing the corpus record
- **THEN** the detection test fails
