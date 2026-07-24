# Documentation Architecture

This document defines how `ff-sec-actions` documentation should help Consumer
Engineers, Platform Maintainers, and Rollout Operators find and complete their
work without reading workflow implementation.

## Design Decision

Documentation is a product surface with its own navigation, compatibility
contract, ownership, and release tests. The repository README is a router, not
the complete handbook.

Start with repository-native Markdown. Keep paths and page contracts compatible
with a future generated documentation site, but do not make a site a
prerequisite for a trustworthy v1.

## Audience Entrances

The README must present three obvious entrances before implementation detail:

| Audience | First question | Primary destination |
|---|---|---|
| Consumer Engineer | “How do I add the right security checks to my project?” | Consumer quickstart and profile chooser |
| Platform Maintainer | “How do I safely change or extend this platform?” | Maintainer architecture and contribution guide |
| Rollout Operator | “How do I deploy, govern, and monitor this across projects?” | Rollout and operating guide |

“Developer” should not appear as an undifferentiated audience: a Consumer
Engineer configuring a workflow and a Platform Maintainer changing the workflow
have different trust boundaries and tasks.

## Navigation Model

```text
README.md                         # purpose, audience router, five-minute start
docs/
├── README.md                     # documentation home and complete navigation
├── consumers/
│   ├── quickstart.md             # shortest safe path to a green first run
│   ├── choose-a-profile.md       # project signals → Security Profile
│   ├── understand-results.md     # completion, findings, evidence, gates
│   ├── configure-policy.md       # advisory → blocking rollout
│   ├── permissions-and-secrets.md
│   ├── fork-pull-requests.md
│   ├── customize-and-suppress.md
│   ├── upgrade-and-rollback.md
│   └── troubleshooting.md
├── profiles/
│   ├── go-node.md
│   ├── rust-fvm-actor.md
│   ├── solidity-fevm.md
│   ├── service-application.md
│   └── infrastructure.md
├── maintainers/
│   ├── architecture.md
│   ├── security-model.md
│   ├── add-an-evaluation.md
│   ├── add-a-profile.md
│   ├── prompts-and-ai.md
│   ├── testing.md
│   ├── releases.md
│   └── compatibility.md
├── operators/
│   ├── rollout.md
│   ├── policy-and-exceptions.md
│   ├── inventory-and-health.md
│   ├── support.md
│   └── incident-and-rollback.md
└── reference/
    ├── workflows.md              # generated inputs, outputs, permissions
    ├── actions.md                # generated inputs and outputs
    ├── result-schema.md
    ├── profiles.md               # supported tools and coverage matrix
    └── version-policy.md
examples/
├── baseline.yml
├── go-node.yml
├── rust-fvm-actor.yml
├── solidity-fevm.yml
├── service-application.yml
└── infrastructure.yml
```

The exact profile set remains governed by `profile-taxonomy`; the structure is
stable even if profile names change.

## Consumer Journey

A Consumer Engineer should be able to:

1. Land on the README and choose “Use this in my project.”
2. Identify a Security Profile from repository signals and examples.
3. Copy one minimal workflow pinned to a real immutable release.
4. See prerequisites before copying, including permissions, secrets, product
   availability, fork behavior, cost, and whether project code executes.
5. Run advisory mode and recognize `complete`, `incomplete`, `skipped`, and
   `error` separately from finding severity.
6. Understand where evidence lives and how to triage a finding.
7. Tighten the Merge Gate using a documented rollout path.
8. Customize through supported configuration without copying implementation.
9. Upgrade or roll back from a versioned change record.

The quickstart is complete only when a fresh Consumer Project can reach a
correctly interpreted first result without consulting workflow source.

## Maintainer Journey

A Platform Maintainer should be able to:

1. Understand the execution graph and trust boundaries.
2. Locate the owner and contract of an action, workflow, profile, prompt, or
   result field.
3. Add one evaluation through a documented adapter pattern.
4. Add or change a Security Profile without duplicating scanner logic.
5. Run static, unit, adversarial, documentation, and consumer-contract tests.
6. Determine compatibility and release impact before opening a PR.
7. Publish an immutable release and validate its complete dependency graph.
8. Diagnose and roll back a broken release using a documented procedure.

Implementation conventions belong here rather than below the consumer
quickstart in the root README.

## Operator Journey

A Rollout Operator should be able to:

1. Inventory candidate Consumer Projects and their detected profiles.
2. Choose advisory and gating policy by project criticality.
3. Install or propose pinned consumer workflows at scale.
4. See adoption, completion, drift, exceptions, and release versions.
5. Route findings and support requests to named owners.
6. Pause, roll back, or revoke a broken platform release.
7. Review effectiveness metrics without receiving Consumer Project code or
   secrets centrally unless that authority is explicitly designed.

## Page Contract

Every task page must answer, in this order:

1. **Who is this for?**
2. **What outcome will it produce?**
3. **What authority and prerequisites does it need?**
4. **What exact configuration should be added?**
5. **What should a successful and incomplete run look like?**
6. **What can go wrong and how is it diagnosed?**
7. **What is the next task?**

Every workflow, action, profile, and result-schema page must state:

- stability and introduced version;
- immutable consumption example;
- permissions, secrets, network access, and code-execution behavior;
- inputs, defaults, outputs, completion behavior, and failure behavior;
- supported events and fork behavior;
- artifacts and retention;
- compatibility and deprecation notes;
- owning team or CODEOWNERS path.

## Source Of Truth

Avoid maintaining defaults and contracts independently in YAML and Markdown.

- Generate reference tables from action metadata, `workflow_call` metadata,
  profile manifests, and result schemas.
- Keep narrative guidance, trade-offs, and task sequences handwritten.
- Keep executable examples as standalone YAML files; include or link them
  rather than maintaining divergent snippets.
- Give every example a declared profile, event, permission set, release ref,
  and expected completion status.
- Version documentation with the implementation. Clearly label documentation
  for unreleased `main`.

## Documentation Verification

The Control Repository cannot release when documentation and implementation
disagree. CI must verify:

- Markdown format and internal/external links;
- a complete navigation index with no orphan pages;
- every YAML example parses with Actionlint;
- every `uses:` target exists and meets the release-pinning policy;
- documented action/workflow inputs, defaults, outputs, permissions, and
  secrets match metadata;
- every released Security Profile has a guide and working example;
- examples run against sandbox Consumer Projects for supported event classes;
- deprecated inputs and profiles point to migration guidance;
- the README audience routes and quickstart links remain valid.

Fixture-based checks must cover missing secrets, fork PRs, incomplete scans,
tool failures, findings above and below policy, upgrades, and rollback.

## Release-Gate Requirements

| Gate | Documentation requirement |
|---|---|
| G0 | Existing examples are executable, unsafe claims are removed, trust requirements are explicit, and documentation-contract CI runs on every PR. |
| G1 | One Consumer Engineer completes the baseline/profile quickstart in a sandbox without source-code assistance; one Platform Maintainer completes the contribution path. |
| G2 | Every pilot profile has a guide, tested example, coverage statement, known limitations, and upgrade path; operator rollout documentation is exercised. |
| G3 | README router, documentation home, all three audience paths, generated reference, version policy, support policy, and release-specific migration notes are complete. |
| G4 | Documentation feedback, failed-journey telemetry, stale-page ownership, and recurring usability reviews feed the platform roadmap. |

## Acceptance Measures

Before public v1:

- a new Consumer Engineer can select a profile and open a working pinned PR
  using only published documentation;
- the quickstart contains no placeholder refs or organization-specific edits;
- every documented example is continuously exercised;
- no manual reference table can drift from workflow/action metadata;
- every incomplete or skipped path is visible in the guide and expected output;
- a Platform Maintainer can determine the required tests and release impact of
  a change without tribal knowledge;
- a Rollout Operator can identify installed version, completion health,
  exception owner, and rollback procedure for every managed project.

## Migration From Current Documentation

1. Reduce the root README to purpose, trust promise, audience navigation,
   five-minute start, project status, and support.
2. Replace the monolithic `docs/CONSUMING.md` with the consumer navigation tree;
   preserve redirects or compatibility links.
3. Move contribution implementation details from the README into
   `docs/maintainers/`.
4. Add the documentation home, profile chooser, result interpretation, and
   permission/trust pages before adding more scanners.
5. Convert current examples into profile-oriented, executable contract
   fixtures.
6. Generate reference pages from source metadata and enforce them in CI.
7. Add operator guidance before multi-project rollout begins.
