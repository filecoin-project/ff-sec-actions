# G0 Trustworthy-Foundation Gate

**For:** Platform Maintainers preparing a consumer pilot or changing a G0 trust
boundary.

**Outcome:** one required GitHub check proves the pre-v1 consumer surface still
satisfies every trustworthy-foundation control.

## Required Check

Configure branch protection and release qualification to require the
`G0 Trustworthy Foundation` job from
[`.github/workflows/g0-contract.yml`](../../.github/workflows/g0-contract.yml).
It runs on every pull request and every push to `main`; it has only
`contents: read` and checks out complete history without persisting credentials.

## Control Matrix

| Claim | Positive contract | Rejecting evidence |
|---|---|---|
| Exact job permissions and safe checkout | `check-workflow-security.sh` | `test-workflow-security.sh` mutates permissions and checkout behavior |
| Classified execution trust | `check-execution-trust.sh` | implementation/manifest disagreement fails the check |
| Baseline does not execute Consumer Project code | `check-baseline-no-exec.sh` | `test-baseline-no-exec.sh` plants a lifecycle hook and an unsafe install step |
| Findings, tool failure, and policy are separate | `check-scanner-gates.sh` | `test-scanner-outcome.sh` covers findings, malformed SARIF, failure, and cancellation |
| Findings are actionable and evidence is discoverable | `check-output-contract.sh` | `test-output-contract.sh` removes remediation guidance from a normalized evaluation |
| Completion is never inferred from green status | Evaluation Result schema check | `test-evaluation-result.sh` covers complete, incomplete, skipped, and error outputs |
| Secret scanning is secretless and scoped | checksum-pinned Gitleaks adapter | `test-gitleaks-scan.sh` plants credentials and tests PR-range/full-history behavior |
| Consumer workflow definitions are evaluated | pinned Zizmor workflow | `test-consumer-actions-security.sh` plants unsafe triggers, refs, permissions, interpolation, checkout, OIDC, and invalid YAML |
| Ecosystem rules detect supported language fixtures | digest-pinned Semgrep image | `test-ecosystem-baseline.sh` requires detections in Go, Rust, JavaScript, Solidity, and Dockerfile fixtures |
| One pin selects the complete immutable graph | `check-release-graph.sh` | `test-release-graph.sh` mutates refs, image digests, nested workflows, and assets |
| Fork PRs stay inside read-only, secretless boundaries | `check-fork-pr.sh` | `test-fork-pr.sh` mutates all eight fork boundaries |
| Consumer examples remain valid contracts | documentation, authority, trust, and syntax checks | any stale permission, mutable pin, unsafe input, or invalid YAML fails G0 |

## Run Locally

Run the exact suite through the workflow commands, or run the individual
scripts while developing. Network-backed tests download checksum- or
commit-pinned tools, so a local offline run may need a pre-populated tool cache.

```bash
bash scripts/check-docs.sh
bash scripts/check-release-graph.sh
bash scripts/test-release-graph.sh
bash scripts/check-fork-pr.sh
bash scripts/test-fork-pr.sh
```

Do not publish or advance a consumer pin while the G0 job is missing, skipped,
or failing. A repository administrator must still make the job required in
GitHub branch protection; checking in the workflow cannot change that setting.

## Next

- [Platform Maintainer guide](README.md)
- [Release integrity](../reference/release-integrity.md)
- [Fork pull-request safety](../reference/fork-pr-safety.md)
