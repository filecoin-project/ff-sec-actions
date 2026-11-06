# Spec Delta

## Purpose

Guarantees that one consumer-facing commit SHA selects the complete, immutable execution graph, so Consumer Projects can adopt, upgrade, and roll back by changing a single reviewed value.

## ADDED Requirements

### Requirement: Consumers install by one full commit SHA
The platform SHALL be consumed as a public reusable workflow referenced by a reviewed 40-character commit SHA. Release documentation and generated examples SHALL use the full release commit, never a branch or floating tag. Upgrade and rollback SHALL require changing only that one value.

#### Scenario: Example uses a mutable reference
- **WHEN** a released consumer example references a reusable workflow by branch or tag
- **THEN** release verification rejects the example

#### Scenario: Example selects an unpublished release
- **WHEN** the Ecosystem Baseline consumer example pins a commit that does not contain the baseline workflow
- **THEN** release verification rejects the example

### Requirement: The pin covers the whole transitive execution graph
Every released entrypoint SHALL transitively pin nested workflows and third-party actions by full commit, container images by sha256 digest, and repository-owned composite actions at an immutable asset commit that also selects their scripts, schemas, prompts, rules, and verified tool-download metadata.

#### Scenario: Mutable nested reference
- **WHEN** any workflow reachable from a released entrypoint uses a mutable action or workflow reference
- **THEN** the release-graph check fails and names the reference

#### Scenario: Container without digest
- **WHEN** a reachable workflow or Docker action uses a container image without a sha256 digest
- **THEN** the release-graph check fails

#### Scenario: Worktree-relative action
- **WHEN** a reachable workflow uses a `./` local action reference
- **THEN** the release-graph check fails

#### Scenario: Missing expected asset
- **WHEN** a repository-owned action reference does not select the assets its expected-assets contract lists
- **THEN** the release-graph check fails

### Requirement: Tool versions are exact and verified
Every fetched scanner or tool SHALL be selected by an exact version marker recorded in the release-graph manifest, and downloaded archives SHALL be verified against recorded checksums.

#### Scenario: Missing exact-version marker
- **WHEN** a pinned path no longer contains its required immutable tool marker
- **THEN** the release-graph check fails

### Requirement: Every supported entrypoint receives the same guarantee
The release-graph manifest SHALL list every supported reusable-workflow entrypoint, so a consumer calling an individual leaf workflow receives the same integrity check as a caller of the umbrella workflow.

#### Scenario: Leaf workflow called directly
- **WHEN** a supported leaf workflow is called directly at a released SHA
- **THEN** its transitive graph has been verified by the same release-graph check as the umbrella
