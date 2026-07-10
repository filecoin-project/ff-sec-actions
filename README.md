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
│   └── manual-ai-code-review.yml # workflow_dispatch test harness (runs the local action)
├── scripts/                      # Standalone scripts runnable outside any action
├── prompts/                      # Domain knowledge as data, not code
│   ├── base-reviewer.md          # Always included: review behavior + output rules
│   ├── filecoin.md               # Filecoin/FVM/Lotus/FEVM domain context
│   └── default.md                # Generic fallback for non-Filecoin repos
└── examples/                     # Copy-paste workflows for consumer repos
    └── consumer-ai-code-review.yml
```

---

# Using this repository in your project

There are three ways to consume this repo, from highest-level to lowest-level.
All of them pin a release tag (`@v1`) — see [Versioning](#versioning-and-rollout).

## 1. Reusable workflows (recommended)

A reusable workflow is a complete job: permissions, runner, and steps are
pre-wired. You call it with `uses:` at the **job** level.

```yaml
# .github/workflows/ai-review.yml in your repo
name: AI Code Review
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

concurrency:
  group: ai-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  review:
    if: ${{ !github.event.pull_request.draft }}
    uses: filecoin-project/ff-sec-actions/.github/workflows/ai-code-review.yml@v1
    with:
      domain: filecoin            # picks prompts/filecoin.md
      fail-on-severity: none      # or: critical | high | medium
    secrets:
      anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Prerequisite: an `ANTHROPIC_API_KEY` **organization secret** scoped to the
repos that need it (Org settings → Secrets and variables → Actions).

Consuming a **private** central repo also requires allowing access: this repo's
Settings → Actions → General → "Accessible from repositories in the
organization".

## 2. Composite actions

Use the action directly when you want the step inside your own job — custom
setup, matrix builds, chaining with other steps, or acting on the outputs.

```yaml
jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write        # needed to post the review comment
    steps:
      - uses: filecoin-project/ff-sec-actions/actions/ai-code-review@v1
        id: ai
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          domain: filecoin

      # Outputs are available to later steps:
      - if: steps.ai.outputs.highest-severity == 'critical'
        run: echo "::error::Critical finding — page the security channel" && exit 1
```

Every action documents its inputs/outputs in its `action.yml` and in the
per-action section below.

## 3. Standalone scripts

Scripts under `scripts/` (and action-internal scripts, at your own risk) can be
run outside GitHub Actions — locally, in another CI system, or in a cron job.
Two patterns:

**a. Sparse checkout of this repo in your job:**

```yaml
steps:
  - uses: actions/checkout@v4
    with:
      repository: filecoin-project/ff-sec-actions
      ref: v1                      # or a full SHA for the strictest pinning
      path: .ff-sec
  - run: bash .ff-sec/scripts/<script>.sh
    env:
      # see the script's header comment for required env vars
```

**b. Locally, from a clone:**

```sh
git clone --depth 1 --branch v1 https://github.com/filecoin-project/ff-sec-actions
bash ff-sec-action/scripts/<script>.sh
```

Every standalone script declares its required env vars at the top of the file
and fails fast with a clear message when one is missing. Example — running the
AI review against any PR from your terminal:

```sh
PR_NUMBER=123 REPO=filecoin-project/some-repo \
ANTHROPIC_API_KEY=... GH_TOKEN=$(gh auth token) \
PROMPT_FILE=prompts/filecoin.md BASE_PROMPT_FILE=prompts/base-reviewer.md \
SCHEMA_FILE=actions/ai-code-review/scripts/schema.json \
POST_COMMENT=false \
bash actions/ai-code-review/scripts/review.sh
```

## Choosing a trigger

| Trigger | Use for | Notes |
|---|---|---|
| `pull_request` | Review every PR before merge | The default. Fork PRs don't get org secrets — internal PRs reviewed, fork PRs skipped, which is the safe default. |
| `push` (branch-filtered) | Auditing commits landing on release/main branches | Pair with a commit-oriented action variant (roadmap). |
| `schedule` | Periodic full-repo or dependency sweeps | For future audit actions. |
| `workflow_dispatch` | Manual/on-demand runs | Useful while trialing an action. |

Avoid `pull_request_target` unless you fully understand the secret-exposure
tradeoffs for forks.

## Action catalog

### `actions/ai-code-review`

Reviews the PR diff with the Claude API using a domain prompt, returns
schema-enforced findings, posts a sticky PR comment, and can gate the job on
severity. Operates on the diff via the GitHub API — **never checks out or
executes PR code**.

| Input | Default | Notes |
|---|---|---|
| `anthropic-api-key` | — (required) | Pass from secrets |
| `github-token` | `${{ github.token }}` | Needs `pull-requests: write` to comment |
| `pr-number` | current PR event | Set explicitly for `workflow_dispatch` runs |
| `repo` | current repository | Cross-repo runs need a `github-token` with access to that repo |
| `model` | `claude-opus-4-8` | Any current Claude model ID |
| `domain` | `filecoin` | Resolves `prompts/<domain>.md` |
| `prompt-file` | `""` | Absolute path override; beats `domain` |
| `effort` | `high` | `low` \| `medium` \| `high` \| `max` |
| `max-tokens` | `16000` | Response budget |
| `max-diff-bytes` | `400000` | Diff truncated beyond this |
| `exclude-pattern` | built-in | Extended regex of paths to drop from the diff |
| `fail-on-severity` | `none` | `none` \| `critical` \| `high` \| `medium` \| `low` |
| `post-comment` | `true` | Set `false` for summary/outputs only |

Outputs: `findings-count`, `highest-severity`, `findings-json` (path to the raw
JSON, usable by downstream steps for artifacts or custom gating).

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
5. Add a consumer example in `examples/` and a section in this README's
   [Action catalog](#action-catalog).

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
  [Standalone scripts](#3-standalone-scripts)) — use a real PR in a sandbox
  repo and `POST_COMMENT=false`-style flags.
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
