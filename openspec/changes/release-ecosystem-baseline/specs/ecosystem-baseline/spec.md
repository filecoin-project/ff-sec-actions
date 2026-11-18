## MODIFIED Requirements

### Requirement: Limitations are explicit
Each baseline result SHALL record coverage it cannot provide, including installed or build-generated dependencies and unsupported source patterns, as limitations. A clean result SHALL mean only that the declared checks completed over the reported scope.

#### Scenario: Build-generated dependencies
- **WHEN** a project's dependency set depends on a build step
- **THEN** the dependency result lists that as a limitation rather than claiming full coverage

#### Scenario: Partially parsed source
- **WHEN** Semgrep cannot fully parse a scanned file
- **THEN** both the `semgrep-baseline` and `semgrep-foc` results list that file as a limitation and remain `complete`

#### Scenario: Manifest without a lockfile
- **WHEN** a `package.json` has no lockfile in its directory or any ancestor, or a `Cargo.toml` has no `Cargo.lock` in its directory or any ancestor
- **THEN** the `trivy-dependencies` result lists that manifest as a limitation

#### Scenario: Solidity dependencies vendored as submodules
- **WHEN** a Foundry project declares Git submodules for its dependencies
- **THEN** the `trivy-dependencies` result records that those dependencies are not scanned

## ADDED Requirements

### Requirement: Static-analysis exclusions are always reported
A Consumer Project `.semgrepignore` file or inline `nosemgrep` comment SHALL NOT remove baseline static-analysis coverage without the exclusion being reported. Files skipped by an ignore file SHALL be recorded as coverage exclusions with their count and source, and suppressed results SHALL be counted as suppressions.

#### Scenario: Consumer ignore file hides a planted defect
- **WHEN** a Consumer Project `.semgrepignore` excludes a directory containing a `tx.origin` authorization
- **THEN** `semgrep-baseline` records an exclusion naming the Consumer Project `.semgrepignore`, the number of files excluded, and the excluded path

#### Scenario: Semgrep default ignore list applies
- **WHEN** the Consumer Project has no `.semgrepignore` and has source under `test/`
- **THEN** the result records those files as excluded by the Semgrep default ignore list

#### Scenario: Inline suppression of a planted defect
- **WHEN** a planted `tx.origin` authorization carries `// nosemgrep`
- **THEN** `semgrep-baseline` reports it as one suppression with source `semgrep-inline`, not as a finding

### Requirement: Planted defects are detected in every supported ecosystem
The baseline's evaluations SHALL detect a planted high-confidence defect in each supported ecosystem of a monorepo fixture without executing it. The ecosystems are:
- Go, Rust, JavaScript, and Solidity source and dependencies.
- Infrastructure configuration.

#### Scenario: Vulnerable lockfile entries
- **WHEN** the fixture's JavaScript, Rust, and Go dependency files pin versions with published high or critical advisories
- **THEN** `trivy-dependencies` reports a finding for each of the three ecosystems

#### Scenario: Infrastructure misconfiguration
- **WHEN** the fixture contains a planted infrastructure misconfiguration
- **THEN** `trivy-iac` reports a finding at that file

#### Scenario: Source defects
- **WHEN** the fixture contains the planted Go, Rust, JavaScript, Solidity, and Dockerfile source defects
- **THEN** `semgrep-baseline` reports each one on its annotated line
