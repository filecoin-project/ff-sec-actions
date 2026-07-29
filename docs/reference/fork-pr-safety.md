# Fork Pull-Request Safety

**For:** Consumer Engineers accepting external contributions and Platform
Maintainers changing baseline workflows.

**Outcome:** useful baseline evaluation on an ordinary fork
`pull_request` without secrets, write authority, OIDC, persistent checkout
credentials, shared caches, self-hosted runners, or Consumer Project code
execution.

## Tested Consumer Shape

The executable [`fork-pr` fixture](../../test/fixtures/fork-pr/workflow.yml)
calls every workflow declared in the non-executing baseline policy:

- GitHub Actions definition analysis;
- manifest and lockfile dependency analysis;
- manifest and lockfile license analysis;
- PR-range secret detection;
- source-manifest SBOM generation.

The caller and each called job cap authority at `contents: read`. No secrets are
forwarded. A called workflow may declare a broader permission for non-fork
publication, but GitHub cannot elevate its effective token above the caller's
cap. The fork-safe caller therefore cannot publish SARIF or comments; its
scanner artifacts and job results remain the evidence surface.

## Boundary Contract

The fixture uses only `pull_request`. `pull_request_target` is forbidden across
consumer workflows because it would introduce a privileged base-repository
context that is easy to combine unsafely with fork-controlled content.

Every pinned baseline workflow is checked for:

- no secret context;
- no OIDC or write authority available from the caller;
- checkout of the event ref with `persist-credentials: false`;
- no cache or self-hosted runner;
- no shell step that executes Consumer Project-controlled behavior;
- a reviewed full commit reference.

The untrusted side of the fixture contains lifecycle, token, secret, OIDC,
self-hosted-runner, and workflow payload probes. The baseline inspects those
files as data and never invokes them.

## Verify Locally

```bash
bash scripts/check-fork-pr.sh
bash scripts/test-fork-pr.sh
```

The contract test proves that mutations adding a write token, secret forwarding,
OIDC, cache, self-hosted runner, consumer-code command, persisted checkout
credential, or privileged trigger are rejected.

This deterministic fixture validates the checked-in and pinned workflow graph;
it does not replace a GitHub-hosted canary that exercises organization-specific
fork settings during release qualification.

## Next

- Consumer: review [permissions and secrets](../consumers/permissions-and-secrets.md).
- Maintainer: review [execution trust](execution-trust.md).
- Operator: include fork behavior in the [pilot checklist](../operators/README.md).
