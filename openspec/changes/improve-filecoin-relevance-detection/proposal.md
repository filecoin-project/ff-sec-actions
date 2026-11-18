# Proposal

## Why

Profile detection is the only place this platform decides whether a repository is part of the Filecoin ecosystem. It does that badly. A planning run of `detect-filecoin-profile` against 12 public Filecoin repositories (recorded in design.md) found:
- **No profile at all** for FilOzone `filecoin-services` (FOC Solidity contracts on FEVM) or `synapse-sdk`.
- **Only `service`** for `filecoin-pin`, and **only `infrastructure`** (from a Dockerfile) for `go-f3` and `lassie`.
- **A high-confidence `storage-provider-infrastructure` result** for a non-Filecoin YAML file containing the words "curious" and "boost".

The detector matches substrings from a short, stale list one manifest at a time. Most Filecoin dependencies give no signal, and it has no notion of "Filecoin-relevant" separate from "fits one profile".

PROF-01 (taxonomy) and PROF-02 (compose evaluations from detection) are built on this output. It needs to be measured and corrected before either starts.

## What Changes

- **Filecoin relevance becomes its own result.** Every component, and the repository as a whole, reports `filecoin_relevance` as `relevant` or `not-detected`, with path-scoped evidence. A new `filecoin-relevance` output carries the repository-level value.
  - Relevance is deliberately broader than profiles: any Filecoin dependency, Filecoin-namespaced module, FEVM network configuration, or Filecoin import counts.
  - A relevant component that fits no profile is reported as such, so PROF-01 sees exactly which projects the taxonomy does not yet cover.
- **Relevance signals move into the versioned catalog.** Go module prefixes, Rust crates, npm packages, Solidity import paths, FEVM chain IDs, and Filecoin RPC hosts live in data, not regular expressions spread through the script.
- **Matching is anchored to declarations:**
  - Go modules are matched on `require` and `module` lines.
  - Cargo dependencies are matched on keys and `package =` values.
  - npm packages are matched on `dependencies`, `devDependencies`, and `peerDependencies` keys, read with `jq`.
  - Solidity is matched on `import` lines.
  - FEVM networks are matched on `chainId`/`chain_id` values and RPC URL hosts in `hardhat.config.*` and `foundry.toml`.
- **Profile rule corrections:**
  - Storage-provider terms match only as whole tokens (`boostd`, `curio`, `lotus-miner`, and so on, never `boost` or `curious`), and never in `.github/` workflow or action YAML.
  - A Solidity component with FOC imports or FEVM network configuration is classified `fevm-contract`. The catalog description is updated to say so.
  - The Synapse SDK, Storacha, and `filecoin-pin` dependencies classify `storage-application`.
- **A measured accuracy corpus:**
  - `profiles/detection-corpus.json` records expected and observed relevance and profiles for Filecoin repositories and non-Filecoin negative controls at pinned commits.
  - A maintainer-only script refreshes it.
  - CI fails if the record is incomplete, if any Filecoin repository is `not-detected`, or if any negative control is `relevant`.
- **Roadmap:** insert **DETECT-01** before PROF-01. PROF-01 and PROF-02 depend on it.
- **Detector version:** the detector goes to 0.2.0, the catalog to 0.3.0, and the detection result `schema_version` to 2. Fields are additive, but consumers that pin `schema_version == 1` must update.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `profile-detection`:
  - Adds the component and repository Filecoin relevance result and output.
  - Adds anchored, catalog-defined relevance signals.
  - Corrects the storage-provider, FEVM, and storage-application rules.
  - Adds the accuracy corpus requirement.
  - Updates the outputs list and the catalog's profile description.

## Impact

- **Detector:** `actions/detect-filecoin-profile/` (script, `action.yml` output) and `profiles/filecoin-project-profiles.json` (relevance signals, `fevm-contract` description, version).
- **New files:** `profiles/detection-corpus.json`, `scripts/measure-detection-accuracy.sh` (maintainer-only, network), and fixtures under `test/fixtures/profile-detection/` for each signal kind and each false-positive case.
- **Tests:** `scripts/test-detect-filecoin-profile.sh` (fixtures and corpus record).
- **Contracts:** `security/output-contract.json` (the new required output), plus `docs.yml` and `g0-contract.yml` if new scripts are added.
- **Roadmap:** `roadmap/state.json`, with DETECT-01 at order 20 and later orders shifted.
- **Docs:**
  - `docs/reference/profile-detection.md`
  - `docs/consumers/choose-a-profile.md`
  - `examples/consumer-profile-detection.yml`, re-pinned in release layers, so the PR is merged with a merge commit.
- **Not affected:** the Ecosystem Baseline. It does not run detection.
- **Sequencing:** only one roadmap task may be in progress, so this change and `release-ecosystem-baseline` (BASE-01) are applied one after the other.
