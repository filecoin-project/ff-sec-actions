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
