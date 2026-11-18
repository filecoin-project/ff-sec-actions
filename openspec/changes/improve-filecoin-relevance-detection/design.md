# Design

## Context

`actions/detect-filecoin-profile/detect-filecoin-profile.sh` (detector 0.1.0, catalog 0.2.0, result `schema_version` 1) finds manifests, Solidity, Terraform, Dockerfiles, and YAML with `find`. It then applies hard-coded `grep -E` patterns per file. Only the FOC add-on check reads `package.json` with `jq`. The only caller is `examples/consumer-profile-detection.yml`. The Ecosystem Baseline does not run detection.

**Planning measurement (2026-11-17).** The run used detector 0.1.0 on sparse checkouts of only the files the detector reads, at each repository's default-branch HEAD:

| Repository | HEAD | Expected | Observed profiles |
|---|---|---|---|
| filecoin-project/lotus | 2c3118b | Filecoin node | go-node, infrastructure, storage-provider-infrastructure |
| filecoin-project/curio | 0d49b3d | Storage provider | go-node, fevm-contract, infrastructure, storage-provider-infrastructure |
| filecoin-project/boost | 28c91c3 | Storage provider | go-node, infrastructure, storage-provider-infrastructure |
| filecoin-project/ref-fvm | 639f1ed | FVM | fvm-actor, fevm-contract, infrastructure |
| filecoin-project/builtin-actors | 5478c90 | FVM actors | fvm-actor, fevm-contract, infrastructure |
| filecoin-project/fevm-hardhat-kit | 367d4b5 | FEVM contracts | fevm-contract |
| FilOzone/filecoin-services | 3293f48 | FEVM contracts (FOC) | **none**, FOC add-on only |
| FilOzone/synapse-sdk | 838577e | Storage SDK (FOC) | **none**, 11 components unsupported |
| filecoin-project/filecoin-pin | c60b595 | Storage application | service (from Express) |
| filecoin-project/go-f3 | a1f286d | Consensus library | infrastructure (Dockerfile only) |
| filecoin-project/lassie | c6ba777 | Retrieval client | infrastructure (Dockerfile only) |
| filecoin-project/filecoin-ffi | ab19ba6 | Proofs FFI | storage-provider-infrastructure, from `FIL_PROOFS_PARAMETER_CACHE` in `.github/` YAML only |

A synthetic `ci.yml` containing `echo "I am curious about boost libraries"` produced `storage-provider-infrastructure` at high confidence. The cause is the unanchored, case-insensitive pattern `(lotus-miner|boostd?|curio|...)` applied to every YAML file.

What the missed repositories actually declare, which drives the signal choices:
- **filecoin-services** imports through the `@pdp/` and `@fws-payments/` remappings (`PDPListener`, `FilecoinPayV1`).
- **synapse-sdk** packages are named `@filoz/*` or depend on them.
- **filecoin-pin** depends on `@filoz/synapse-sdk` and `@helia/*`.
- **lassie** requires `github.com/filecoin-project/go-state-types`, `go-data-transfer`, and `go-retrieval-types`.

## Goals / Non-Goals

**Goals:**
- Every Filecoin repository in the corpus is `relevant`, and every negative control is `not-detected`. This is enforced in CI from a recorded measurement.
- Profile signals are anchored to declarations, so ordinary prose cannot select a profile.
- Signal lists are data that reviewers can extend with a catalog edit and a fixture.

**Non-Goals:**
- **New profiles or taxonomy changes** for consensus libraries (go-f3), retrieval clients (lassie), or proofs (filecoin-ffi). PROF-01 owns `profile-taxonomy`. This change makes those projects visible as `relevant` coverage gaps.
- **Source-level detection,** such as viem `filecoin` chain imports in TypeScript or RPC URLs in application code. Only manifests and network configuration files are read.
- **Changing which evaluations run.** Composition is PROF-02.

## Decisions

### 1. Relevance is a separate, broad dimension; profiles stay narrow

Each component gains `filecoin_relevance: {status: "relevant" | "not-detected", evidence: [{path, signal, reason}]}`. The result gains a top-level `filecoin_relevance` that is relevant if any component is relevant, with evidence aggregated from them. The action gains the `filecoin-relevance` output.

Relevance never selects a profile by itself. Ambiguity rules are unchanged: a `go-state-types`-only component is still `ambiguous`, but now also `relevant`. The gap reason for a relevant component without a profile becomes: `Filecoin-relevant component has no supported Filecoin Security Profile`.

The value is `not-detected`, not `not-relevant`. Detection reads a bounded set of files and cannot prove absence.

**Alternative considered:** widen the profile rules until every Filecoin repository gets a profile. Rejected because it forces taxonomy decisions, for example whether go-f3 is a `go-node`, ahead of PROF-01, and turns guesses into classifications.

### 2. Relevance signals are catalog data

`profiles/filecoin-project-profiles.json` (catalog 0.3.0) gains `relevance_signals`, keyed by kind:

| Kind | Matches | Initial entries |
|---|---|---|
| `go-module-prefix` | Path of a `require` line (single or block form) or the `module` line | `github.com/filecoin-project/`, `github.com/FilOzone/`, `github.com/ipfs-force-community/` |
| `cargo-crate` | Dependency key, `package = "..."`, or the `[package]` name; `*` suffix allowed | `fvm`, `fvm_*`, `fil_*`, `filecoin-proofs*`, `storage-proofs-*`, `frc42_*`, `frc46_*` |
| `npm-package` | `dependencies`, `devDependencies`, or `peerDependencies` key, or the own `name`; `/*` scope suffix allowed | `@filoz/*`, `@glif/*`, `@storacha/*`, `@web3-storage/*`, `@filecoin-shipyard/*`, `@lighthouse-web3/sdk`, `@zondax/filecoin-solidity`, `@zondax/izari-filecoin`, `iso-filecoin`, `filecoin-pin`, `filecoin.js` |
| `solidity-import` | Path inside an `import` statement, including multi-line `import {..} from "..."` | `@filoz/`, `@pdp/`, `@fws-payments/`, `@zondax/filecoin-solidity`, `filecoin-solidity`, plus the names `PDPVerifier`, `PDPListener`, `IValidator`, and `FilecoinPay` |
| `fevm-chain-id` | `chainId:` in `hardhat.config.*`, or `chain_id =` in `foundry.toml` | `314`, `314159` |
| `filecoin-rpc-host` | URL host inside `url:` or `rpc_endpoints` values in the same files | `api.node.glif.io`, `api.calibration.node.glif.io`, `calibration.node.glif.io`, `filecoin.chainup.net`, `rpc.ankr.com` (path `/filecoin`) |

The detector validates `relevance_signals` with the existing catalog check. It fails if code references an undefined kind or a kind has no entries.

Matching uses fixed-string comparison on extracted tokens, never on whole-file text:
- **Go:** `awk` extracts module paths from `require` lines and blocks and from the `module` line, ignoring `//` comments.
- **Cargo:** `awk` extracts keys from `[dependencies]`, `[dev-dependencies]`, `[build-dependencies]`, and `[workspace.dependencies]` tables, plus `package =` values and the `[package]` name.
- **npm:** `jq` reads keys and the name. An unparseable manifest is not a signal, as today.
- **Solidity:** `grep -o` extracts quoted paths from `import` statements, after joining lines up to the closing `;`.
- **Network configuration:** `grep -oE` extracts `chainId: <n>`, `chain_id = <n>`, and URL hosts.

The token sets are compared with `jq` against the catalog lists.

**Alternative considered:** keep patterns in the script and only widen them. Rejected because it repeats the stale-list problem and gives no reviewable surface.

### 3. Profile rule corrections

- **`storage-provider-infrastructure`:** the catalog gains a `storage_provider_tokens` list: `lotus-miner`, `boostd`, `booster-http`, `booster-bitswap`, `curio`, `venus-sealer`, `FULLNODE_API_INFO`, `MINER_API_INFO`, `LOTUS_API`, `LOTUS_MINER`, `FIL_PROOFS_PARAMETER_CACHE`.
  - Each token is matched with token boundaries `(^|[^A-Za-z0-9_-])TOKEN($|[^A-Za-z0-9_-])` and case-sensitively, so `curious`, `Curio`, and `boost` do not match.
  - It applies only to `*.tf`, `Dockerfile*`, Kubernetes-kind YAML, `docker-compose*.y*ml` or `compose*.y*ml`, and `*.service` files.
  - Any path under `.github/` is skipped for this rule.
  - A storage-provider match also counts as relevance.
- **`fevm-contract`:** a Solidity component is classified when any of these hold:
  - The existing Zondax or precompile signal matches (high).
  - A `solidity-import` relevance signal matches (high).
  - Its component root (resolved with the existing `find_component_root`) has a `fevm-chain-id` or `filecoin-rpc-host` match (medium).

  The catalog description becomes: `Solidity contracts that use Filecoin actor APIs, precompiles, FEVM-specific libraries, or Filecoin Onchain Cloud interfaces, or that are configured for Filecoin networks.` PROF-01 may revise it.
- **`storage-application`:** the pattern list becomes catalog `storage_application_packages`. It is matched as dependency keys only, not the package's own name, so the SDK library itself is not classified as an application. The list adds `@filoz/synapse-sdk`, `@storacha/*`, and `filecoin-pin`, and keeps the existing entries.

  The FOC add-on is unchanged. A file can now produce both the add-on and a profile, which satisfies the existing add-on requirement: the add-on report itself still changes nothing.

### 4. Accuracy corpus record

`profiles/detection-corpus.json` holds `{schema_version: 1, detector_version, catalog_version, entries: [...]}`. Each entry has `repository`, a full `commit`, `kind` (`filecoin` or `negative-control`), `expected_relevance`, `expected_profiles_note` (free text for PROF-01), and `observed: {filecoin_relevance, profiles, components, gaps}`.

The entries are:
- The 12 repositories above.
- Negative controls:
  - `expressjs/express` (Node service).
  - `foundry-rs/forge-template` (generic Solidity).
  - `NomicFoundation/hardhat-boilerplate` (Ethereum Hardhat).
  - `OpenZeppelin/openzeppelin-contracts`.
  - `boostorg/json`, whose CI and Docker files say "boost".
  - `kubernetes/examples` (Kubernetes YAML).
  - `terraform-aws-modules/terraform-aws-vpc`.

`scripts/measure-detection-accuracy.sh` is maintainer-only and needs network access. It is never run in CI. It sparse-clones each entry at its commit with hooks disabled, runs the current detector, and rewrites `observed`, `detector_version`, and `catalog_version`. It preserves expectations and notes, and a rerun is byte-identical. It follows the `measure-foc-precision.sh` pattern.

`scripts/test-detect-filecoin-profile.sh` checks the record offline. It fails on:
- A missing `observed` value.
- A `filecoin` entry observed `not-detected`.
- A `negative-control` entry observed `relevant`.
- A recorded version that differs from the detector or catalog version.

Tests run without network, so the record cannot be re-executed in CI. Offline fixtures that copy each corpus repository's deciding lines guard the logic itself (decision 5).

**Alternative considered:** cloning the corpus in G0. Rejected because it adds network dependence and runtime to every PR, for a check that only changes when the detector changes.

### 5. Fixtures

New `test/fixtures/profile-detection/` cases, each asserted on relevance, profiles, and gaps:

| Fixture | Covers |
|---|---|
| `foc-contracts/` | Solidity importing `@pdp/PDPVerifier.sol` and `@fws-payments/FilecoinPayV1.sol` → `fevm-contract`, relevant |
| `fevm-network-config/` | Plain Solidity plus `hardhat.config.ts` with `chainId: 314159` → `fevm-contract` medium |
| `ethereum-hardhat/` | Plain Solidity plus `chainId: 1` → not detected (negative) |
| `synapse-app/` | `package.json` depending on `@filoz/synapse-sdk` → `storage-application`, relevant, FOC add-on |
| `sdk-library/` | `package.json` named `@filoz/example` with no dependency → relevant, no profile, gap |
| `filecoin-go-library/` | `go.mod` requiring `github.com/filecoin-project/go-f3` → relevant, gap |
| `commented-mentions/` | Names only in a `go.mod` comment and a `package.json` description → not detected |
| `ci-prose/` | `.github/workflows/ci.yml` with "curious", "boost", and `FIL_PROOFS_PARAMETER_CACHE` → not detected, no storage-provider profile |
| `sp-compose/` | `docker-compose.yml` running `curio` with `FULLNODE_API_INFO` → `storage-provider-infrastructure` |
| `fvm-crate-name/` | `Cargo.toml` with `[package] name = "fvm_ipld_example"` → relevant |

The existing fixtures keep their profiles. Expected changes are recorded in the test:
- `storage-application` stays classified.
- `ambiguous-go` becomes relevant and stays ambiguous.
- `generic-solidity` stays not detected.

### 6. Roadmap

Insert **DETECT-01**, "Measure and correct Filecoin relevance detection":
- Order 20, before PROF-01. Every later order shifts by 1.
- `phase: "security-profiles"`, `priority: "P0"`, `kind: "implementation"`.
- `blocked_by: ["EVAL-01"]`, matching PROF-01.
- `decision_refs: ["execution-trust"]`.
- `artifacts: ["actions/detect-filecoin-profile/", "profiles/"]`.
- Acceptance criteria and verification come from the spec.

PROF-01 and PROF-02 add `DETECT-01` to `blocked_by`, because the taxonomy decision should use the corpus evidence.

`profile-taxonomy` is open and deliberately not referenced, because this change makes no taxonomy decision.

Only one task may be in progress. DETECT-01 is claimed when this change's apply starts, which requires BASE-01 not to be in progress at that time.

### Decision tickets

**`execution-trust`** (resolved) is satisfied:
- Detection still reads only files.
- `awk`, `grep`, and `jq` parse them as data.
- Nothing is compiled, installed, or executed.
- There is no network access, and only `contents: read` is needed.
- The measurement script runs network clones only on a maintainer machine, with hooks disabled.

### Proving checks per scenario

| Scenario | Proving check |
|---|---|
| Solidity that integrates FOC | `foc-contracts/` fixture |
| Solidity deployed to a Filecoin network | `fevm-network-config/` fixture, with `ethereum-hardhat/` as the negative |
| Storage application SDK | `synapse-app/` fixture |
| FVM actor crate, monorepo (existing) | Existing `fvm-actor/` and `mixed/` fixtures |
| Default destinations, add-on empty (existing) | Existing test cases |
| Relevance output | `synapse-app/` (relevant) and `unknown-repository/` (`not-detected`) output assertions |
| Filecoin dependency without a profile | `filecoin-go-library/` fixture |
| No Filecoin signal | `service/` fixture asserts `not-detected` |
| Name only in a comment or string | `commented-mentions/` fixture |
| Catalog references | Test mutates a temporary catalog copy, removes a kind, and expects a nonzero exit |
| Ordinary words in CI YAML, proofs cache variable | `ci-prose/` fixture |
| Storage-provider deployment | `sp-compose/` fixture, plus the existing `storage-provider-infrastructure/` fixture |
| Negative control matches, stale record | Test mutates a temporary record copy (a negative control set to `relevant`, a bumped version) and expects failure |

## Risks / Trade-offs

- **[Broad relevance flags tooling that merely uses a Filecoin library]** → This is intended. Relevance means "part of the Filecoin ecosystem", not "security-critical", and profiles carry the narrower meaning.
- **[An `awk` manifest parser misreads unusual syntax]** → A misparse yields no signal rather than a false one. Fixtures cover block and single-line `require`, inline tables, and workspace dependencies.
- **[The corpus drifts as upstream repositories change]** → Entries are pinned to full SHAs. Refreshing commits is a deliberate maintainer action reviewed in the PR.
- **[`rpc.ankr.com` serves many chains]** → It is matched only with the `/filecoin` path.
- **[`schema_version` 2 breaks a consumer that asserts 1]** → The only known caller is our example. The docs and the PR body call out the bump.
- **[Two changes queued while one task can be in progress]** → They are applied sequentially. The user picks the order.

## Migration Plan

Release layers: commit the detector and catalog, then re-pin `examples/consumer-profile-detection.yml` to that commit, merging with a merge commit. Consumers pinned to the previous detector SHA keep the 0.1.0 behavior until they advance. Rollback is the previous SHA.
