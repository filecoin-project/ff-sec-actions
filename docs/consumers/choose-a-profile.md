# Choose A Security Profile

**For:** a Consumer Engineer deciding which evaluations apply to a project.

**Outcome:** an immutable detector workflow, path-scoped candidate profiles,
and explicit classification gaps to review before enabling specialized checks.

## Authority And Prerequisites

Profile detection needs a GitHub-hosted runner and `contents: read` only. It
uses no secret, write permission, OIDC token, cache, or external analysis
service, and it never installs, builds, or executes Consumer Project code.
Checkout must set `persist-credentials: false`.

The repository remains pre-v1. Use the reviewed full commit in the maintained
example; do not substitute a moving branch or `v1` tag.

## Add The Exact Configuration

Copy
[`examples/consumer-profile-detection.yml`](../../examples/consumer-profile-detection.yml)
to `.github/workflows/filecoin-profile-detection.yml` in the Consumer Project.
The standalone example declares its profile, supported events, read-only
permissions, immutable action references, expected Completion Status, and
durable evidence upload.

The detector action is
`filecoin-project/ff-sec-actions/actions/detect-filecoin-profile`. Its useful
outputs are:

- `completion` for successful detector lifecycle;
- `profiles-json` for path-aware evaluation routing;
- `result-file` for complete evidence and selection reasons;
- `summary` for the readable component table; and
- `coverage-gaps-count` for ambiguous or unsupported components.

## Recognize The Result

A successful run shows `completion=complete`, a component/profile table in the
job summary, and a `filecoin-profile-detection` artifact containing JSON and
Markdown. Every selected profile includes a component path, confidence,
evidence file, and reason.

A complete run may still have coverage gaps. Each ambiguous or unsupported
component appears in the table, result JSON, and a warning annotation. Review
every nonzero `coverage-gaps-count`; do not treat it as classified coverage.

An invalid path, unavailable runner tool, invalid catalog, or filesystem error
fails the action and does not emit a clean Completion Status. Retry only after
diagnosing the operational failure.

## Diagnose A Wrong Or Missing Profile

1. Open the job summary and locate the component path.
2. Download `filecoin-profile-detection` and inspect that component's evidence,
   status, and the document-level limitations.
3. Select a profile manually when project behavior is known but the available
   signal is intentionally ambiguous.
4. For a reusable signal, propose a detector rule with a representative fixture
   and a stable selection reason.
5. Do not suppress or delete the gap without recording the manual decision.

See [Troubleshooting](troubleshooting.md#profile-detection-reports-a-coverage-gap)
for escalation guidance.

## Interpret Candidate Profiles

The secretless [Ecosystem Baseline](ecosystem-baseline.md) remains the default
pilot starting point. Detection chooses candidate specialized profiles; the
Filecoin-specific evaluations attached to those profiles are still being
implemented.

| Project signals | Candidate profile | Current useful evaluations | Important gap |
|---|---|---|---|
| Lotus, Venus, or other Go node code | Go node | Workflow security, Semgrep, CodeQL for Go, dependency and secret scanning | No released Filecoin node rule pack |
| Builtin actors, ref-fvm, or Rust/WASM | Rust/FVM actor | Workflow security, dependency, secret, generic static analysis | No released actor-invariant profile |
| Solidity contracts targeting FEVM | Solidity/FEVM | Workflow security, Slither, dependency, secret scanning | Slither is opt-in and build-dependent |
| TypeScript/JavaScript service or tooling | Service application | Workflow security, Semgrep, CodeQL, dependency review, IaC | Current defaults are closest to this class |
| Terraform, Kubernetes, deployment repositories | Infrastructure | Workflow security, Trivy IaC, secrets, Scorecard | Runtime and cloud-policy coverage is project-specific |
| Several of the above in one repository | Composed path-scoped profiles | Detector emits one or more profiles per recognized component | Specialized evaluations are not all released yet |

## Selection Rules

1. Choose based on security-relevant behavior, not primary language alone.
2. Compose profiles for monorepos instead of forcing one global choice.
3. Record unsupported and ambiguous components as coverage gaps.
4. Treat consensus-critical and funds-moving code as requiring human review
   even when automated evaluation completes.
5. Do not enable build-dependent analysis on untrusted PRs until its execution
   boundary is documented.
6. Review the detector limitations before treating the profile set as complete.

## Next

- [Adopt the Ecosystem Baseline](ecosystem-baseline.md)
- [Understand results](understand-results.md)
- [Review permissions](permissions-and-secrets.md)
