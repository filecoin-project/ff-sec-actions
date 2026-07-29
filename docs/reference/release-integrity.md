# Release Integrity

**For:** Consumer Engineers reviewing an adoption or upgrade, and Platform
Maintainers preparing a release.

**Outcome:** one consumer-facing commit SHA selects the complete execution graph
without resolving mutable branches, floating tags, containers, or repository
assets at runtime.

## Consumer Contract

Use a reviewed 40-character commit SHA in the reusable-workflow reference. To
upgrade or roll back, change that one value. Do not substitute `main`, another
branch, or a version tag.

The selected umbrella commit points to an immutable leaf-workflow commit. Each
leaf pins third-party actions by full commit, pins container images by digest,
and selects repository-owned composite actions at an immutable asset commit.
That asset commit also selects action scripts, schemas, prompts, rules, and
verified scanner-download metadata.

```text
consumer SHA -> umbrella -> leaf workflow SHA -> action/assets SHA
                            |                 -> scripts, prompts, schemas
                            -> action commits
                            -> container digests
                            -> exact tool versions and verified archives
```

This layered graph is intentional: a Git commit cannot contain a reference to
its own as-yet-unknown SHA.

## Maintainer Gate

Run both checks before publishing a consumer SHA:

```bash
bash scripts/check-release-graph.sh
bash scripts/test-release-graph.sh
```

The recursive checker rejects mutable `uses:` references, local worktree action
references, container tags without digests, missing repository-owned action
assets, and absent exact-version markers recorded in
[`security/release-graph.json`](../../security/release-graph.json).

The manifest lists every supported reusable-workflow entrypoint, so consumers
calling an individual workflow receive the same integrity guarantee as callers
of the umbrella.

## Scope Boundary

A full commit pin makes the selected source immutable; it does not establish
that the source is trustworthy. Maintainers still review upstream changes,
artifact provenance, licenses, and behavior before advancing a pin. Consumer
Projects should review the release diff and use dependency automation to
propose, not silently merge, pin updates.

## Next

- Consumer: follow the [quickstart](../consumers/quickstart.md).
- Maintainer: follow the [distribution decision](../decisions/distribution-model.md).
- Operator: use the [rollout guide](../operators/README.md) to coordinate pins.
