# Dev harness: iterate on prompts, schema, and rendering locally

Staged version of `actions/ai-code-review/scripts/review.sh`, split at its
natural seams so each artifact is cached on disk and you only re-run the stage
you changed. Nothing here posts to GitHub or writes outside `fixtures/`.

```
fetch.sh  → fixtures/<name>/pr.json, full.patch, meta.json   (GitHub API)
build.sh  → filtered.patch, diff.patch, request.json          (local, free)
call.sh   → response.json                                     (Claude API, costs money)
render.sh → findings.json, comment.md                         (local, free)
corpus.sh → all of the above across every fixture + summary
```

Each script mirrors the numbered section of `review.sh` it derives from
(noted in its header). **When a change survives here, port it back to
`review.sh` — the harness intentionally duplicates that logic and drifts if
you don't.**

## Setup

```sh
cp scripts/dev/.env.example scripts/dev/.env   # add ANTHROPIC_API_KEY
gh auth status                                  # or set GH_TOKEN in .env
```

`fixtures/` and `.env` are gitignored: fixtures contain real diffs and model
responses; never commit either.

## Typical loops

Snapshot a PR once:

```sh
REPO=relotnek/lotus PR_NUMBER=42 scripts/dev/fetch.sh
```

**Prompt or schema change** — rebuild, inspect, then pay for one call:

```sh
export FIXTURE=relotnek-lotus-pr42
scripts/dev/build.sh
jq -r '.system[1].text' scripts/dev/fixtures/$FIXTURE/request.json | head  # what the model gets
REFRESH=true scripts/dev/call.sh
scripts/dev/render.sh
```

**Renderer or gate change** — cached response, zero API calls:

```sh
scripts/dev/render.sh
FAIL_ON_SEVERITY=high scripts/dev/render.sh   # exercise the gate
```

**Filter/truncation change** — `build.sh` alone, no network at all.

## Corpus as a regression check

One test PR proves nothing about a prompt change. Keep a handful of fixtures
that each pin a behavior:

- a clean PR (should stay quiet)
- a PR with a known planted bug (must still be found)
- a huge diff (exercises `MAX_DIFF_BYTES` truncation)
- a lockfile/vendor-only PR (must filter to empty and exit cleanly)
- a PR whose description contains prompt-injection text (must be reported,
  not obeyed)

After a prompt change:

```sh
for f in scripts/dev/fixtures/*/findings.json; do cp "$f" "$f.prev"; done
REFRESH=true scripts/dev/corpus.sh
diff <(jq . scripts/dev/fixtures/<name>/findings.json.prev) \
     <(jq . scripts/dev/fixtures/<name>/findings.json)
```

The summary table shows findings count, highest severity, and gate result per
fixture; `corpus.sh` exits non-zero if any stage or gate fails.

## Knobs

All stages take the same env vars as the action, with the same defaults:
`MODEL`, `EFFORT`, `MAX_TOKENS`, `MAX_DIFF_BYTES`, `EXCLUDE_RE`, `DOMAIN`
(or `PROMPT_FILE` to bypass domain resolution), `FAIL_ON_SEVERITY`.
`call.sh` reuses a cached `response.json` unless `REFRESH=true`.

## After the harness

Once prompts/schema/renderer are stable here, the remaining integration
surface (input plumbing, `$GITHUB_OUTPUT`, sticky-comment posting) is tested
with the `workflow_dispatch` harness in
`.github/workflows/manual-ai-code-review.yml`, which runs the local action
from a branch.
