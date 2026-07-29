# Distribution Model Decision

Status: Accepted for the initial self-service release

Decision date: 2026-07-28

Owner: Filecoin ecosystem security platform maintainers

## Decision

Publish the baseline, profiles, composite actions, schemas, and documentation
from the public `filecoin-project/ff-sec-actions` repository. Consumers install
one reusable workflow by a reviewed full commit SHA.

```yaml
jobs:
  security:
    permissions:
      contents: read
    uses: filecoin-project/ff-sec-actions/.github/workflows/ecosystem-baseline.yml@0123456789abcdef0123456789abcdef01234567
```

The SHA is the security and rollback boundary. Moving branches and major tags
may be convenience aliases, but release documentation and generated examples
must use the full release commit. That commit must transitively select every
nested workflow, action, prompt, ruleset, tool, archive, and container.

No GitHub App is required for the initial release.

## Why Native Reusable Workflows Are Sufficient

GitHub's access matrix permits public reusable workflows to be called by
public, internal, and private repositories when the caller's Actions policy
allows public dependencies. Nested workflow permissions can only be maintained
or reduced, so a called workflow cannot exceed the caller's permission cap.
GitHub also identifies a full commit SHA as the safest reusable-workflow
reference. See GitHub's [reusable workflow reference](https://docs.github.com/en/enterprise-cloud@latest/actions/reference/workflows-and-actions/reusing-workflow-configurations)
and [calling syntax](https://docs.github.com/en/enterprise-cloud@latest/actions/how-tos/reuse-automations/reuse-workflows).

This gives the initial product what it needs:

- one-file, self-service installation across independently administered
  organizations;
- no installation token, webhook service, database, or always-on control
  plane;
- caller-owned triggers, permissions, branch rules, logs, artifacts, and
  rollback;
- secretless baseline behavior on normal fork `pull_request` events;
- reviewable updates through a pull request that changes one SHA.

Dependabot can propose updates to reusable-workflow references, but a human or
policy bot must still verify the release graph and result changes before merge.
See GitHub's [Actions update support](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/auto-update-actions).

## Access Assumptions

| Consumer | Initial support | Assumption |
|---|---|---|
| Public GitHub.com repository | Supported | Actions permits public actions and reusable workflows |
| Private/internal GitHub.com repository | Supported | Enterprise/repository policy permits this public repository |
| Repository in another organization | Supported | It can reference the public workflow by owner/repository/path/SHA |
| Fork pull request | Baseline supported | Uses `pull_request`, read-only contents, no secrets, writes, OIDC, cache, or self-hosted runner |
| GitHub Enterprise Server | Copy/mirror required | A GHES instance cannot call a workflow hosted only on GitHub.com |
| AI or external provider analysis on a fork | Not baseline | Missing provider authority is `skipped`; no `pull_request_target` checkout workaround |

The public source repository must remain public and retain its owner/name.
GitHub does not redirect renamed actions or reusable workflows. Consumer
organization policy can still block public dependencies; that is an explicit
deployment prerequisite, not something this workflow can bypass.

## Installation, Updates, And Rollback

1. Copy the generated consumer example.
2. Set the caller permission cap shown by the selected profile.
3. Replace the example placeholder with the reviewed 40-character release SHA.
4. Run the consumer contract fixture on `pull_request` and `workflow_dispatch`.
5. Observe before enabling merge gates.
6. Update by reviewing a pull request from the old SHA to a newer release SHA.
7. Roll back by restoring the last known-good SHA; no server-side release
   mutation is required.

Deleting a release commit, making the repository private, or renaming it is a
breaking ecosystem event. Release operations must preserve reachable commits
and publish a revocation notice if a pin becomes unsafe.

## Validation Evidence

On 2026-07-28, a read-only GitHub API query confirmed
`filecoin-project/ff-sec-actions` is public. An unauthenticated HTTPS probe then
retrieved `.github/workflows/security-pipeline.yml` at commit
`f816e783c0230a4c0f9d74c8e925f04e5a4a7c7c`. This proves that an independently
administered caller can resolve the selected public owner/repository/path/SHA
form without a control-repository credential. The commit is accessibility
evidence only; it is not an approved release.

`G0-09` must prove the complete transitive graph at a candidate release SHA,
and `G0-10`/`BASE-01` must run the generated caller in a sandbox consumer before
public v1.

## When A GitHub App Becomes Justified

Revisit this decision only when measured pilot evidence shows that native
Actions cannot meet a requirement. A GitHub App proposal must identify at
least one of these triggers:

- more than 20% of supported consumers remain over two approved releases
  behind for 30 days despite update pull requests;
- required checks, installation health, or profile selection cannot be
  validated across organizations through documented APIs and rollout tooling;
- fork contributions need a centralized no-checkout publisher or external
  analysis flow that cannot be made safe with a normal `pull_request` plus
  maintainer-approved dispatch;
- evidence must be retained or queried centrally under a documented governance
  requirement that caller-owned artifacts cannot satisfy;
- onboarding volume makes repository-by-repository installation the dominant
  rollout failure, supported by incident and support data.

Convenience alone is not enough. An App adds an installation-token trust
boundary, webhook verification, credential rotation, tenancy isolation,
availability, audit logging, incident response, and data-retention duties.

If approved later, the App must remain narrowly scoped: repository metadata and
checks read/write only where required, no contents write, no secrets access, no
fork-head checkout in a privileged context, short-lived installation tokens,
verified webhooks, per-installation isolation, and an explicit uninstall and
rollback path.

## Consequences

The initial model favors auditability, autonomy, and low operational burden.
It does not centrally enforce installation, prevent a repository administrator
from weakening its caller, or provide a global evidence database. Rollout
inventory and drift reporting remain operator responsibilities until evidence
justifies a stronger control plane.
