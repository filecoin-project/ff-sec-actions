# Standalone scripts

Scripts here are runnable outside GitHub Actions — locally, in another CI
system, or on a schedule. Conventions (enforced in review):

- Configuration by environment variables only; header comment lists required
  and optional vars.
- `set -euo pipefail` and `: "${VAR:?VAR is required}"` guards at the top.
- Read-only by default; writes require an explicit env flag.
- No secrets in argv; never echo secret values.

See the "Adding a standalone script" section in the repo README before adding
one. If a script earns a permanent place in CI, promote it to a composite
action under `actions/`.

## Roadmap State

`roadmap.sh` validates, queries, and deliberately updates the canonical
implementation queue in [`roadmap/state.json`](../roadmap/state.json). Run
`bash scripts/roadmap.sh help` for its command contract. Mutations require
`ROADMAP_ALLOW_WRITE=true`; reads and validation are the default. The isolated
contract suite is `bash scripts/test-roadmap.sh`.

## Workflow Security

`check-workflow-security.sh` compares every maintained workflow and consumer
example with [`security/workflow-policy.json`](../security/workflow-policy.json).
It rejects unlisted jobs, implicit or policy-incompatible permissions, and any
checkout without `persist-credentials: false`. Its public CLI accepts optional
workflow paths for focused checks; the no-argument form validates the complete
repository. Run its negative fixture suite with
`bash scripts/test-workflow-security.sh`.

`check-baseline-no-exec.sh` protects the manifest-inspection seam for
dependency, license, and SBOM evaluation. It rejects shell steps,
package-manager inputs, and actions outside the reviewed allowlist in
[`security/baseline-policy.json`](../security/baseline-policy.json). Run the
malicious lifecycle-hook fixture with `bash scripts/test-baseline-no-exec.sh`.

`check-scanner-gates.sh` verifies that each configurable scanner gate is
exposed, enforced, and forwarded through the umbrella according to
[`security/scanner-gates.json`](../security/scanner-gates.json). The
`actions/scanner-outcome` module validates SARIF and separates advisory or
blocking findings from operational failure. Exercise its public interface with
`bash scripts/test-scanner-outcome.sh`.

`check-output-contract.sh` requires every reusable workflow and composite
action to declare a consumer and remediation surface in
[`security/output-contract.json`](../security/output-contract.json). Normalized
evaluations must expose a readable summary, source annotations, actionable
remediation, a stable Evaluation Result artifact, and a named raw-evidence
artifact. Its negative suite is `bash scripts/test-output-contract.sh`.

`check-workflow-docs.sh` requires exactly one reviewable Markdown contract in
[`docs/workflows/`](../docs/workflows/README.md) for every reusable
`workflow_call` entrypoint. It checks lifecycle metadata, required consumer
sections, source/index links, and every declared workflow input and output. Run
its rejecting fixture suite with `bash scripts/test-workflow-docs.sh`.
