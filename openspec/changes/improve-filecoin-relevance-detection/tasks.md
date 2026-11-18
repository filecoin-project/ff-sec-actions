# Tasks

## 1. Roadmap

- [ ] 1.1 Insert DETECT-01 into `roadmap/state.json` per design decision 6: order 20, later orders shifted by 1, and `DETECT-01` added to the `blocked_by` of PROF-01 and PROF-02. Verify `bash scripts/roadmap.sh validate` and `bash scripts/test-roadmap.sh` pass.
- [ ] 1.2 Confirm BASE-01 is not in progress, then claim with `ROADMAP_ALLOW_WRITE=true bash scripts/roadmap.sh claim DETECT-01 improve-filecoin-relevance-detection`. Verify `roadmap.sh validate` shows DETECT-01 `in_progress`.

## 2. Catalog

- [ ] 2.1 Add `relevance_signals` (six kinds), `storage_provider_tokens`, and `storage_application_packages` to `profiles/filecoin-project-profiles.json` per design decisions 2 and 3. Update the `fevm-contract` description and bump `catalog_version` to `0.3.0`. Extend the detector's catalog validation to fail on a missing or empty kind. Verify with a test case that mutates a temporary catalog copy, removes a kind, and expects a nonzero exit.

## 3. Anchored relevance detection

- [ ] 3.1 Implement token extraction for `go.mod` (`require` single and block forms and `module`, comments ignored), `Cargo.toml` (dependency tables, `package =`, and `[package] name`), `package.json` (dependency keys and `name`, read with `jq`), Solidity `import` paths (multi-line), and network configuration (`chainId`, `chain_id`, URL hosts). Compare the tokens against the catalog. Verify with the `commented-mentions/`, `filecoin-go-library/`, `sdk-library/`, and `fvm-crate-name/` fixtures.
- [ ] 3.2 Add per-component and repository `filecoin_relevance` with evidence (`path`, `signal`, `reason`), the gap reason for relevant components without a profile, the `filecoin-relevance` action output, and a summary line with the relevant-component count. Set the result `schema_version` to 2 and the detector version to `0.2.0`. Verify with fixture assertions: `synapse-app/` gives `relevant`, while `unknown-repository/` and `service/` give `not-detected`. Also check that the summary escapes evidence paths.
- [ ] 3.3 Declare `filecoin-relevance` as a required output in `security/output-contract.json` and in `actions/detect-filecoin-profile/action.yml`. Verify `bash scripts/check-output-contract.sh` and `bash scripts/test-output-contract.sh` pass.

## 4. Profile rule corrections

- [ ] 4.1 Replace the storage-provider pattern with whole-token, case-sensitive matching of `storage_provider_tokens`. Limit it to Terraform, Dockerfile, Kubernetes-kind YAML, Compose, and `*.service` files, and skip `.github/`. Verify with the `ci-prose/` fixture (no profile and `not-detected`), the `sp-compose/` fixture, and the existing `storage-provider-infrastructure/` fixture.
- [ ] 4.2 Classify `fevm-contract` from `solidity-import` signals (high) and from component-root FEVM chain ID or RPC host configuration (medium). Verify with the `foc-contracts/`, `fevm-network-config/`, and `ethereum-hardhat/` (negative) fixtures, and with the existing `fevm-contract/` and `generic-solidity/` fixtures unchanged.
- [ ] 4.3 Drive `storage-application` from `storage_application_packages`, matching dependency keys only. Verify with `synapse-app/` (profile and FOC add-on), `sdk-library/` (relevant, no profile), and the existing `storage-application/` fixture.
- [ ] 4.4 Update `scripts/test-detect-filecoin-profile.sh` for every new fixture and the recorded expectation changes for existing fixtures (`ambiguous-go` is now relevant and still ambiguous). Verify the full test passes and `shellcheck` is clean.

## 5. Accuracy corpus

- [ ] 5.1 Write `scripts/measure-detection-accuracy.sh` per design decision 4. It is maintainer-only and uses the network: sparse clones at full SHAs with hooks disabled, the current detector, preserved expectations, and byte-identical reruns. Verify with `shellcheck` and two consecutive runs that produce no diff.
- [ ] 5.2 Resolve full SHAs for the 12 Filecoin repositories and the 7 negative controls. Write the expectations and run the script to produce `profiles/detection-corpus.json`. Verify every Filecoin entry is observed `relevant` and every negative control `not-detected`. Iterate on the catalog and fixtures until that holds, and record any rule change in this task.
- [ ] 5.3 Add offline record checks to `test-detect-filecoin-profile.sh`: completeness, Filecoin entries relevant, negative controls not relevant, and versions match. Include mutation cases on a temporary copy (a negative control flipped to `relevant`, a stale version). Verify the checks pass on the real record and fail on each mutation.
- [ ] 5.4 Add `scripts/measure-detection-accuracy.sh` and `profiles/detection-corpus.json` to the `check-docs.sh` required pages. Verify `bash scripts/check-docs.sh` passes.

## 6. Release and documentation

- [ ] 6.1 Commit the detector and catalog asset layer, then re-pin `examples/consumer-profile-detection.yml` to that commit. Verify `bash scripts/extract-workflow-doc-examples.sh`, `bash scripts/check-release-graph.sh`, and `bash scripts/test-release-graph.sh` pass.
- [ ] 6.2 Update `docs/reference/profile-detection.md`: relevance versus profiles, signal kinds and how to add one with a fixture, schema version 2, and the corpus and how to refresh it. Also update `docs/consumers/choose-a-profile.md` (reading `filecoin-relevance` and relevant gaps) and `docs/reference/current-contracts.md` (detector 0.2.0, catalog 0.3.0). Verify `bash scripts/check-docs.sh` and `bash scripts/check-workflow-docs.sh` pass.
- [ ] 6.3 Run every G0 step locally in order, using the pinned actionlint image. Then push the branch and open the PR with the measurement table, the release layers, and the merge-commit instruction. Verify the G0 and Documentation Contract runs succeed.

## Workflow follow-up

- Archive with `/opsx:archive improve-filecoin-relevance-detection` after merge. Archiving marks DETECT-01 done.
- PROF-01 uses `profiles/detection-corpus.json` (`expected_profiles_note` and relevant gaps) as input for the taxonomy decision.
