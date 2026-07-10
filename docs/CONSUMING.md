# Using ff-sec-actions in your repository

Everything a consumer repo needs, top to bottom. You never copy code from this
repo — you add small workflow files that reference it, and updates roll out
when this repo's tags move.

> **Current ref:** use `@main` until a `v1` release is tagged, then switch to
> `@v1`. Repos needing reproducible behavior can pin a full version or SHA.

## Quick start

1. **Secrets** (once, org level ideally — Org settings → Secrets and variables
   → Actions):
   - `ANTHROPIC_API_KEY` — for the AI code review.
   - `GITLEAKS_LICENSE` — for secret scanning on org-owned repos (optional
     otherwise).
2. **Optional repo/org variable:** `ENABLE_GHAS='true'` uploads scanner SARIF
   to the repo's Security tab (needs GitHub Advanced Security on private
   repos).
3. **Add workflows** to your repo — copy from [`examples/`](../examples/):

   | You want | Copy to `.github/workflows/` |
   |---|---|
   | AI review on every PR | [`consumer-ai-code-review.yml`](../examples/consumer-ai-code-review.yml) |
   | AI review on demand (Actions tab) | [`consumer-manual-ai-code-review.yml`](../examples/consumer-manual-ai-code-review.yml) |
   | Full security pipeline (Semgrep, Trivy, Gitleaks, SBOM, …) | [`consumer-security-pipeline.yml`](../examples/consumer-security-pipeline.yml) |

That's it. The rest of this document is reference.

## The three consumption surfaces

**Reusable workflows** (recommended) — a complete job, pre-wired. Referenced at
the **job** level; your workflow's `on:` triggers drive it (PR, push, schedule,
manual — anything):

```yaml
jobs:
  review:
    uses: filecoin-project/ff-sec-actions/.github/workflows/ai-code-review.yml@main
    with: { domain: filecoin }
    secrets: { anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }} }
```

**Composite actions** — a single step inside a job *you* define, for custom
setup, matrices, or chaining with your own steps. Referenced at the **step**
level; you own the job's `permissions`:

```yaml
jobs:
  review:
    runs-on: ubuntu-latest
    permissions: { contents: read, pull-requests: write }
    steps:
      - uses: filecoin-project/ff-sec-actions/actions/ai-code-review@main
        id: ai
        with: { anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }} }
      - if: steps.ai.outputs.highest-severity == 'critical'
        run: exit 1
```

**Standalone scripts** — run outside Actions entirely (locally, other CI).
Sparse-checkout this repo and invoke with env vars:

```yaml
steps:
  - uses: actions/checkout@v4
    with: { repository: filecoin-project/ff-sec-actions, ref: main, path: .ff-sec }
  - run: bash .ff-sec/scripts/<script>.sh   # env vars per the script's header
```

Or from a terminal:

```sh
PR_NUMBER=123 REPO=filecoin-project/some-repo \
ANTHROPIC_API_KEY=... GH_TOKEN=$(gh auth token) \
PROMPT_FILE=prompts/filecoin.md BASE_PROMPT_FILE=prompts/base-reviewer.md \
SCHEMA_FILE=actions/ai-code-review/scripts/schema.json \
POST_COMMENT=false \
bash actions/ai-code-review/scripts/review.sh
```

## AI code review

Reviews the PR diff with the Claude API using a Filecoin-aware domain prompt,
posts a sticky PR comment with structured findings, and can gate the job on
severity. Operates on the diff via the GitHub API — **never checks out or
executes PR code**, so it's safe on any PR and needs no build environment.

Surfaces: reusable workflow `ai-code-review.yml`, composite action
`actions/ai-code-review`. Same inputs on both:

| Input | Default | Notes |
|---|---|---|
| `anthropic-api-key` | — (required) | Pass from secrets |
| `github-token` | `${{ github.token }}` | Needs `pull-requests: write` to comment |
| `pr-number` | current PR event | Set explicitly for `workflow_dispatch` runs |
| `repo` | current repository | Cross-repo runs need a `github-token` with access |
| `model` | `claude-opus-4-8` | Any current Claude model ID |
| `domain` | `filecoin` | Resolves `prompts/<domain>.md` in this repo |
| `prompt-file` | `""` | Path override; beats `domain` |
| `effort` | `high` | `low` \| `medium` \| `high` \| `max` |
| `max-tokens` | `16000` | Response budget |
| `max-diff-bytes` | `400000` | Diff truncated beyond this |
| `exclude-pattern` | built-in | Regex of paths dropped from the diff (lockfiles, vendored, generated) |
| `fail-on-severity` | `none` | `none` \| `critical` \| `high` \| `medium` \| `low` |
| `post-comment` | `true` | `false` = job summary/outputs only |

Outputs: `findings-count`, `highest-severity`, `findings-json`.

Suggested rollout: start with `fail-on-severity: none`, watch the signal for a
few weeks, then tighten to `critical`.

## Security pipeline

The org's standard scanner suite (ported from fil-one), as parallel jobs. Two
modes:

**Umbrella — everything in one `uses:` line.** Copy
[`consumer-security-pipeline.yml`](../examples/consumer-security-pipeline.yml);
the core is:

```yaml
permissions:            # callers must grant what the jobs need
  actions: read
  contents: read
  security-events: write
  pull-requests: write  # dependency-review PR comments
  id-token: write       # OpenSSF Scorecard

jobs:
  security:
    uses: filecoin-project/ff-sec-actions/.github/workflows/security-pipeline.yml@main
    with:
      package-manager: pnpm          # pnpm | npm | none (Go/Rust/etc.)
      skip-dirs: node_modules
      # enable-codeql: true          # requires GHAS
      # enable-slither: true         # Solidity/Foundry repos
      # enable-scorecard: true
    secrets:
      gitleaks-license: ${{ secrets.GITLEAKS_LICENSE }}
```

Defaults: Semgrep, dependency scan, Gitleaks, IaC scan, licenses,
dependency-review (PRs), and SBOM (pushes/schedule) are **on**; CodeQL,
Scorecard, and Slither are **opt-in**.

**À la carte — any scanner as its own job:**

| Workflow | What it runs | Default posture |
|---|---|---|
| `sec-semgrep.yml` | Custom rules (`.semgrep.yml`, auto-detected) + community rulesets | Advisory (`blocking` input to gate) |
| `sec-codeql.yml` | CodeQL, `languages` JSON-array input | Requires GHAS |
| `sec-dependencies.yml` | pnpm/npm audit (optional) + Trivy fs scan | Advisory |
| `sec-secrets.yml` | Gitleaks over full history (`.gitleaks.toml` auto-detected) | **Blocking** |
| `sec-iac.yml` | Trivy IaC misconfiguration scan | Advisory |
| `sec-licenses.yml` | Trivy license scan | Advisory |
| `sec-dependency-review.yml` | New/changed deps on PRs, license denylist | Blocking at `high` |
| `sec-sbom.yml` | CycloneDX SBOM (Anchore/Syft) | Informational |
| `sec-scorecard.yml` | OpenSSF Scorecard | Advisory |
| `sec-slither.yml` | Slither for Foundry/Solidity (`slither.config.json` auto-detected) | Advisory |

```yaml
jobs:
  semgrep:
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-semgrep.yml@main
  secrets-scan:
    uses: filecoin-project/ff-sec-actions/.github/workflows/sec-secrets.yml@main
    secrets: { gitleaks-license: ${{ secrets.GITLEAKS_LICENSE }} }
```

**Conventions all scanners share:**

- Results upload as artifacts always; to the Security tab when the calling repo
  sets `ENABLE_GHAS='true'`.
- Repo config files (`.semgrep.yml`, `.gitleaks.toml`, `.trivyignore`,
  `slither.config.json`) are auto-detected — present: used; absent: skipped.
  The same workflow drops into any repo unchanged.
- Advisory by default; flip per-scanner `blocking` inputs to gate merges.
- Every third-party action is SHA-pinned.

## Choosing triggers

Your workflow's `on:` block drives everything (reusable workflows inherit the
caller's event):

| Trigger | Use for | Notes |
|---|---|---|
| `pull_request` | Review/scan every PR | Fork PRs don't get org secrets — internal PRs run, fork PRs skip, which is the safe default. |
| `push` (branch-filtered) | Auditing what lands on main/release | |
| `schedule` | Weekly full scans, SBOM refresh | fil-one uses `0 2 * * 0`. |
| `workflow_dispatch` | On-demand runs | The file must be on your default branch before the Run-workflow button appears. |

Avoid `pull_request_target` unless you fully understand the secret-exposure
tradeoffs for forks.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `repository not found` / 404 on the `uses:` line | Wrong slug (it's `ff-sec-actions`, plural) — or this repo is private and hasn't allowed org access (ff-sec-actions Settings → Actions → General → Access). Private actions are only shareable within the same org/account. |
| `Can't find 'action.yml' ... under .../actions/ai-code-review` | You copied the **maintainer harness** (which uses a local `./actions/...` path that only exists in ff-sec-actions). Use [`consumer-manual-ai-code-review.yml`](../examples/consumer-manual-ai-code-review.yml) — remote `uses:`, no checkout. |
| `ANTHROPIC_API_KEY is required` | Secret not visible to your repo — org secret not scoped to it, or (personal repos) not set at repo level. |
| No Run-workflow button for a dispatch workflow | The workflow file isn't on your default branch yet. |
| Scanner findings not in the Security tab | Set the repo/org variable `ENABLE_GHAS='true'` (and have GHAS on private repos). Artifacts are uploaded regardless. |
| Reusable-workflow job fails on permissions | Your calling workflow's `permissions:` grant caps the called jobs — copy the block from the security-pipeline example. |
