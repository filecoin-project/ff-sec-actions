# ff-sec-action

Central repository for organization-wide GitHub Actions focused on code quality,
security inspection, and CI evaluation — with domain context the generic web3 /
static-analysis tooling lacks (Filecoin first: FVM actors, Lotus, FEVM, storage
provider tooling).

Consumer repositories reference this repo for **composite actions**, **reusable
workflows**, and **standalone scripts**, so review logic, prompts, and policy
live in one place and roll out to every repo by bumping a tag.

Replace `filecoin-project` throughout with the GitHub organization this repo lives in.

## Repository layout

```
ff-sec-action/
├── actions/                      # Composite actions (embed as a step in an existing job)
│   └── ai-code-review/
│       ├── action.yml
│       └── scripts/              # Implementation details of that action only
│           ├── review.sh
│           └── schema.json
├── .github/workflows/            # Reusable workflows (whole job, workflow_call)
│   ├── ai-code-review.yml
│   ├── manual-ai-code-review.yml # workflow_dispatch test harness (runs the local action)
│   ├── security-pipeline.yml     # Umbrella: full security pipeline with scanner toggles
│   └── sec-*.yml                 # Individual scanners (semgrep, codeql, dependencies,
│                                 #   secrets, iac, licenses, dependency-review, sbom,
│                                 #   scorecard, slither) — callable à la carte
├── scripts/                      # Standalone scripts runnable outside any action
├── prompts/                      # Domain knowledge as data, not code
│   ├── base-reviewer.md          # Always included: review behavior + output rules
│   ├── filecoin.md               # Filecoin/FVM/Lotus/FEVM domain context
│   └── default.md                # Generic fallback for non-Filecoin repos
├── docs/
│   └── CONSUMING.md              # Full consumer guide (start here to use this repo)
└── examples/                     # Copy-paste workflows for consumer repos
    ├── consumer-ai-code-review.yml
    ├── consumer-manual-ai-code-review.yml
    └── consumer-security-pipeline.yml
```

---

# Using this repository in your project

**Full consumer guide: [docs/CONSUMING.md](docs/CONSUMING.md)** — quick start,
all inputs/outputs, trigger guidance, and troubleshooting. The short version:

1. Set the `ANTHROPIC_API_KEY` (and optionally `GITLEAKS_LICENSE`) org secrets.
2. Copy the workflow you want from [`examples/`](examples/) into your repo's
   `.github/workflows/`:
   - `consumer-ai-code-review.yml` — AI review on every PR
   - `consumer-manual-ai-code-review.yml` — AI review on demand
   - `consumer-security-pipeline.yml` — the full scanner suite (Semgrep, Trivy,
     Gitleaks, CodeQL, SBOM, Scorecard, Slither, …)
3. Use `@main` until a `v1` tag exists, then pin `@v1`.

Three consumption surfaces, in order of preference: **reusable workflows**
(whole pre-wired job), **composite actions** (a step inside your own job), and
**standalone scripts** (outside Actions entirely). All are documented with
copy-paste examples in [docs/CONSUMING.md](docs/CONSUMING.md).

---

# Contributing: adding your own actions, workflows, and scripts

Everything in this repo follows one rule: **consumers pin `@v1` and must not
break** — so additions are cheap, but changes to existing inputs/outputs are
release events. See [Versioning](#versioning-and-rollout).

## Adding a composite action

1. Create `actions/<your-action>/action.yml`. Skeleton:

   ```yaml
   name: Your Action
   description: One sentence — what it does and what it never does.
   inputs:
     some-input:
       description: ...
       required: false
       default: "sane-default"
   outputs:
     some-output:
       description: ...
       value: ${{ steps.main.outputs.some_output }}
   runs:
     using: composite
     steps:
       - id: main
         shell: bash
         env:
           SOME_INPUT: ${{ inputs.some-input }}
           ACTION_PATH: ${{ github.action_path }}
         run: bash "${ACTION_PATH}/scripts/main.sh"
   ```

2. Put the implementation in `actions/<your-action>/scripts/` — keep
   `action.yml` thin (env mapping + one script call) so the logic is testable
   outside Actions.
3. Conventions the existing actions follow — match them:
   - **Inputs** are kebab-case; **env vars/outputs inside scripts** are
     SNAKE_CASE. Every input has a default unless it's a secret.
   - Scripts start with `set -euo pipefail` and validate required env vars
     with `: "${VAR:?VAR is required}"` so they fail fast and run standalone.
   - No PR code execution unless the action's purpose requires it — prefer
     operating on diffs/metadata via the GitHub API.
   - Treat repo content, PR text, and diffs as untrusted input.
   - Write a `$GITHUB_STEP_SUMMARY` and set outputs via `$GITHUB_OUTPUT`.
   - Only shell + `jq` + `gh` + `curl` (preinstalled on GitHub runners). If you
     need more, install it in a step and document why.
4. If the action is AI-backed, don't inline prompts — put shared behavior in
   `prompts/` and reference it, so prompt improvements ship independently.
5. Add a consumer example in `examples/` and document inputs/outputs in
   [docs/CONSUMING.md](docs/CONSUMING.md).

## Adding a reusable workflow

Add `.github/workflows/<name>.yml` with an `on: workflow_call:` trigger:

```yaml
on:
  workflow_call:
    inputs:
      some-input: { type: string, required: false, default: "..." }
    secrets:
      some-secret: { required: true }
    outputs:
      some-output: { value: ${{ jobs.main.outputs.some-output }} }
```

Guidelines:

- A reusable workflow should be a thin wrapper around a composite action in
  this repo: it owns `runs-on`, `permissions` (least privilege), and secret
  plumbing — the action owns the logic. That keeps both surfaces in sync.
- Reference the sibling action by **full path with a tag**
  (`uses: filecoin-project/ff-sec-actions/actions/<name>@v1`), not a relative path —
  relative references don't resolve without a checkout. Keep the tag in sync
  when releasing (grep for `@v1` before tagging).
- Mirror the composite action's inputs 1:1 with the same names and defaults so
  users can switch surfaces without relearning.

## Adding a standalone script

1. Add it to `scripts/` at the repo root, executable, with this header shape:

   ```bash
   #!/usr/bin/env bash
   # <name>: one-line purpose.
   # Required env: FOO, BAR. Optional: BAZ (default: ...).
   # Safe to run locally and in CI; makes no writes unless WRITE=true.
   set -euo pipefail
   : "${FOO:?FOO is required}"
   ```

2. Rules:
   - Configuration by **environment variables only** (no positional args) —
     this is what lets the same script run in an action step, another CI
     system, or a terminal without a wrapper.
   - Default to **read-only / dry-run**; require an explicit env flag for any
     write (posting comments, creating issues, mutating state).
   - Degrade gracefully outside Actions:
     `GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"` etc.
   - No secrets in argv (visible in `ps`) and never echo secret values.
3. If a script becomes useful in CI regularly, promote it: wrap it in a
   composite action (see above) rather than having consumers call it raw.

## Adding a domain prompt (AI actions)

1. Add `prompts/<name>.md`. Follow the shape of `prompts/filecoin.md`:
   - an **ecosystem map** (what components/layers exist, what language, what
     trust level),
   - **invariants** ("must always hold; violation is a finding"),
   - **known bug classes** with the concrete patterns to look for,
   - **severity calibration** for the domain,
   - an explicit "when this domain doesn't apply, review as ordinary software"
     escape hatch — prevents invented findings.
2. Nothing else changes: consumers select it with `domain: <name>`.
3. Prompt-only changes are minor releases; they roll out automatically to
   everyone on `@v1`.

## Testing your contribution

- **Static checks** (run before every PR):
  ```sh
  bash -n actions/**/scripts/*.sh scripts/*.sh   # shell syntax
  shellcheck actions/**/scripts/*.sh scripts/*.sh
  jq empty actions/**/scripts/*.json             # JSON validity
  ```
- **Local dry-run:** every script must be runnable locally with env vars (see
  the standalone-scripts section of [docs/CONSUMING.md](docs/CONSUMING.md)) —
  use a real PR in a sandbox repo and `POST_COMMENT=false`-style flags.
- **Manual run (fastest end-to-end):** Actions tab → "AI Code Review (manual)"
  → Run workflow. Pick your branch, give it a PR number (any PR in this repo,
  or another repo via the `repo` input + a `GH_PAT` secret). It checks out the
  selected branch and runs the **local** action, so branch changes are tested
  before any tag exists. `post-comment` defaults to `false` — results land in
  the job summary.
- **End-to-end from a consumer:** open a PR against a sandbox repo whose
  workflow points at your branch:
  `uses: filecoin-project/ff-sec-actions/actions/<name>@<your-branch>`.
  Verify the comment, job summary, outputs, and the failure gate.
- PRs to this repo get reviewed by the org security team (add a `CODEOWNERS`
  entry for your action's directory if you want ownership).

## Versioning and rollout

- Release with semver tags: `v1.0.0`, `v1.1.0`, …
- Maintain a moving major tag (`v1`) that consumers pin:
  `git tag -f v1 v1.2.0 && git push -f origin v1`
- **Major** (`v2`): renamed/removed inputs or outputs, changed default
  behavior that could break a consumer's gate.
- **Minor**: new actions, new optional inputs, prompt improvements.
- **Patch**: bug fixes.
- Before tagging, grep the repo for `@v1` (reusable workflows reference sibling
  actions by tag) and confirm they point where you expect.
- Repos needing reproducible behavior can pin the full version or a commit SHA.

---

# Security model

- **No PR code execution.** The AI review operates on the diff via the API
  only. There is nothing for a malicious PR to run.
- **Prompt-injection containment.** PR diffs and descriptions are untrusted
  input to the model. The base prompt instructs the model to treat diff content
  as data and to report injection attempts as findings; the action's blast
  radius is limited regardless — its only write capability is posting a PR
  comment (`pull-requests: write`, `contents: read`).
- Use plain `pull_request` triggers; avoid `pull_request_target`.
- Consumers should pin tags (or SHAs, for the strictest posture).
- If you point `model` at `claude-fable-5`, note its safety classifiers target
  cybersecurity content and may occasionally decline security-heavy diffs; the
  action handles the refusal gracefully (logs and skips), but
  `claude-opus-4-8` is the recommended default for this workload.

# Roadmap (future actions in this repo)

- `actions/dependency-review` — org policy over `dependency-review-action` with
  a curated deny/alert list for web3 supply-chain incidents.
- `actions/semgrep-filecoin` — Semgrep with custom rules for actor/FVM patterns
  generic rulesets miss (determinism, CBOR handling, epoch math).
- `actions/commit-audit` — push/commit-triggered variant of the AI review for
  release branches (same engine, different trigger and prompt emphasis).
- SARIF output from `ai-code-review` for the GitHub code-scanning UI.
