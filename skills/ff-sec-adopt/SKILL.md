---
name: ff-sec-adopt
description: Add the ff-sec-actions security workflows that fit a Filecoin ecosystem project. Inspects the repository, runs the non-executing Filecoin profile detector, selects the Ecosystem Baseline plus only the specialized or privileged evaluations the project's context justifies, and writes immutably pinned GitHub workflows in advisory mode. Use when a Consumer Engineer asks to "add ff-sec-actions", "add security scanning/checks", "set up the Filecoin security baseline", "which ff-sec-actions workflows should we use", or to add AI review, Slither, CodeQL, Scorecard, or dependency review from filecoin-project/ff-sec-actions.
license: MIT
metadata:
  author: Filecoin ecosystem security platform maintainers
  version: "0.1.0"
  source: https://github.com/filecoin-project/ff-sec-actions/tree/main/skills/ff-sec-adopt
---

# Adopt ff-sec-actions In A Consumer Project

You are helping a **Consumer Engineer** add security evaluation from the
**Control Repository** `filecoin-project/ff-sec-actions` to the repository you
are working in (the **Consumer Project**). The goal is the smallest set of
workflows that gives this project useful evidence, with every grant of
authority (secrets, write permissions, project-code execution) chosen
deliberately by the user.

The platform is **pre-v1**. Every `uses:` reference must be a reviewed
40-character commit SHA copied from the Control Repository. Never write
`@main`, `@v1`, or any branch/tag, and never invent or "update" a SHA.

## Ground Rules

1. **The Control Repository is the source of truth.** Copy workflow YAML from
   its `examples/` files and the "Immutable Usage" blocks in
   `docs/workflows/<workflow>.md`. Do not rely on SHAs or inputs remembered
   from elsewhere, including this skill.
2. **Start with the Ecosystem Baseline.** It is secretless, read-only, and does
   not execute project code. Everything else is an addition justified by the
   project's context.
3. **Authority is the user's decision.** Anything needing a secret,
   `pull-requests: write`, `security-events: write`, `id-token: write`, or
   project build execution must be confirmed by the user before you add it.
4. **Advisory first.** Add finding gates as `false` and keep
   `require-complete: true`. Recommend enforcing gates only after the first
   results are triaged.
5. **Never use `pull_request_target`**, never set `persist-credentials: true`,
   and never broaden a job's `permissions` beyond the documented cap.
6. **Do not commit, push, or open a PR** unless the user asks.

## Step 1: Fetch The Control Repository

Clone it read-only into a temporary directory outside the Consumer Project
(use a scratch directory if your environment provides one):

```bash
ctl="$(mktemp -d)/ff-sec-actions"
git clone --quiet --filter=blob:none https://github.com/filecoin-project/ff-sec-actions "$ctl"
git -C "$ctl" log -1 --format='%H %cs %s'
```

Then read, at minimum:

- `$ctl/docs/consumers/quickstart.md`
- `$ctl/docs/consumers/choose-a-profile.md`
- `$ctl/docs/consumers/permissions-and-secrets.md`
- `$ctl/docs/workflows/README.md`
- every file in `$ctl/examples/`

Read `$ctl/docs/workflows/<workflow>.md` for each workflow you consider adding.
If cloning fails (no network, blocked host), stop and tell the user; do not
fall back to guessed YAML.

## Step 2: Understand The Project Context

Inspect the Consumer Project without running its code (no installs, builds,
tests, or package scripts). Record:

| Signal | How to look |
|---|---|
| Existing workflows | `.github/workflows/*.yml`; note any existing security, CodeQL, Dependabot, or `ff-sec-actions` usage and its pins |
| Languages and manifests | `go.mod`, `Cargo.toml`, `package.json` + lockfiles, `foundry.toml`, `hardhat.config.*`, `*.sol`, `pyproject.toml`, etc. |
| Filecoin role | Lotus/Venus deps, FVM SDK/actor crates, FEVM precompiles or Filecoin Solidity libs, storage clients, storage-provider software (Curio, Boost, Lotus Miner) |
| Infrastructure | Terraform, Kubernetes manifests, Helm, Dockerfiles |
| Repository visibility | `gh repo view --json visibility,isFork` if `gh` is available, otherwise ask |
| Fork contributions | Whether outside contributors open PRs from forks (affects secrets and build-executing jobs) |
| Default branch | `git symbolic-ref refs/remotes/origin/HEAD` or ask; examples assume `main` |
| Vendored or generated dirs | Directories to put in `skip-dirs` (e.g. `node_modules`, `vendor`, `target`, `dist`, `contracts/lib`) |

### Run The Profile Detector

The detector classifies path-scoped components into Filecoin Security Profiles
by reading files only. Run the exact version the consumer example pins:

```bash
det_sha="$(grep -Eo 'detect-filecoin-profile@[0-9a-f]{40}' "$ctl/examples/consumer-profile-detection.yml" | cut -d@ -f2)"
git -C "$ctl" -c advice.detachedHead=false checkout --quiet "$det_sha"
out="$(mktemp -d)"
REPOSITORY_PATH="$PWD" RESULT_FILE="$out/profiles.json" SUMMARY_FILE="$out/profiles.md" \
  bash "$ctl/actions/detect-filecoin-profile/detect-filecoin-profile.sh"
cat "$out/profiles.md"
git -C "$ctl" checkout --quiet -   # return to the default branch for docs
```

It requires `jq`. Treat every ambiguous or unsupported component as a
**coverage gap** to report, not as covered. If the detector cannot run, fall
back to the manual signals above and say so.

## Step 3: Select Components

Use [references/component-catalog.md](references/component-catalog.md) to map
the context to components. In short:

- **Always:** Ecosystem Baseline (`examples/consumer-ecosystem-baseline.yml`).
- **Recommended for any repo with more than one component or a Filecoin
  profile:** Profile detection (`examples/consumer-profile-detection.yml`), so
  classification evidence and coverage gaps stay visible over time.
- **Context-driven, low authority:** Dependency Review on PRs
  (`pull-requests: write`), License Compliance, SBOM.
- **Context-driven, privileged (ask first):** AI Code Review (Anthropic key,
  PR comment write), Slither (Solidity build execution + `security-events: write`),
  CodeQL (autobuild execution + GitHub Code Security), Scorecard (public repos,
  OIDC + `security-events: write`).

Do **not** add individual scanners that the Ecosystem Baseline already runs
(Zizmor, Gitleaks, Trivy dependencies, Trivy IaC, Semgrep) as separate
workflows. Do not add the legacy `security-pipeline.yml` umbrella to a new
adoption; only keep or migrate it if the project already uses it.

Present the proposed set to the user as a short table: component, why it fits
this project, authority it needs, and whether it runs project code. For every
privileged component, ask a direct yes/no question before adding it. Batch
these questions into one prompt.

## Step 4: Write The Workflows

For each accepted component, create one file under `.github/workflows/`:

| Component | File in Consumer Project | Copy from |
|---|---|---|
| Ecosystem Baseline | `security-baseline.yml` | `examples/consumer-ecosystem-baseline.yml` |
| Profile detection | `filecoin-profile-detection.yml` | `examples/consumer-profile-detection.yml` |
| AI Code Review (PR) | `ai-code-review.yml` | `examples/consumer-ai-code-review.yml` |
| AI Code Review (manual) | `ai-review-manual.yml` | `examples/consumer-manual-ai-code-review.yml` |
| Other workflows | `<workflow-name>.yml` | "Immutable Usage" in `docs/workflows/<workflow>.md` |

When copying:

- Keep every `uses:` SHA, `permissions` block, and trigger exactly as the source
  has them. You may adapt only: `skip-dirs`, the default-branch name under
  `push.branches`, `with:` inputs documented in that workflow's doc page (e.g.
  Slither `target`/`solc-version`, CodeQL `languages`), and the schedule.
- Fill inputs from evidence (e.g. CodeQL `languages` from detected languages,
  Slither `target` from where `foundry.toml` or the contracts live). Put a
  one-line comment above any input you changed explaining why.
- Privileged build-executing workflows (CodeQL, Slither) are documented as
  `legacy-mixed`. If the project accepts fork PRs, trigger them with
  `workflow_dispatch`, `push` to the default branch, and/or `schedule` only,
  not `pull_request`, and say why in a comment.
- Leave all `*-blocking` inputs `false` and `require-complete: true`.
- If a file with the same name or purpose already exists, show the user the
  difference and ask before overwriting or replacing it.

Then validate locally if tools are available: `actionlint` on the new files,
and a YAML parse otherwise. Confirm with `grep -n 'uses:'` that every
`ff-sec-actions` reference ends in a 40-character hex SHA.

## Step 5: Hand Off

Report to the user:

1. **Files added**, each with its trigger, permissions, secrets, and whether it
   executes project code.
2. **The pinned Control Repository commits** used, and that they are the
   rollback/upgrade boundary (upgrade = review the diff, then change only the
   SHA).
3. **Prerequisites they must satisfy**, only those that apply:
   organization Actions policy allowing `filecoin-project/ff-sec-actions`,
   GitHub-owned actions and `aquasecurity/trivy-action`; an
   `ANTHROPIC_API_KEY` secret for AI review; GitHub Code Security for CodeQL;
   `ENABLE_GHAS='true'` variable if they want SARIF in the Security tab.
4. **First-run acceptance checks** from the quickstart: five baseline
   evaluations complete, `Profile Conclusion` reflects the bundle,
   `ecosystem-baseline-evidence` artifact present, no job received a secret or
   write token it should not have.
5. **Coverage gaps**: detector ambiguities/unsupported components, and the
   detected profiles' `planned_evaluations` from
   `profiles/filecoin-project-profiles.json` that are not released yet. State
   plainly that consumption of these workflows produces evidence, not a
   certification, and that consensus-critical or funds-moving code still needs
   human review.
6. **Next steps**: run on a pilot PR; after triage, require `Profile
   Conclusion` (not individual scanner jobs) in branch protection; then enable
   the finding gates the team is ready to enforce, one at a time.

Remove the temporary Control Repository clone when done.
