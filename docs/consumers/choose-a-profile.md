# Choose A Security Profile

**For:** a Consumer Engineer deciding which evaluations apply to a project.

**Outcome:** a documented profile choice with known coverage gaps.

The secretless [Ecosystem Baseline](ecosystem-baseline.md) is the default pilot
starting point. The path-scoped detector can now identify candidate specialized
profiles and explicit gaps; the Filecoin-specific evaluations attached to those
profiles remain under implementation.

| Project signals | Candidate profile | Current useful evaluations | Important gap |
|---|---|---|---|
| Lotus, Venus, or other Go node code | Go node | Workflow security, Semgrep, CodeQL for Go, dependency and secret scanning | No released Filecoin node rule pack |
| Builtin actors, ref-fvm, or Rust/WASM | Rust/FVM actor | Workflow security, dependency, secret, generic static analysis | No released actor-invariant profile |
| Solidity contracts targeting FEVM | Solidity/FEVM | Workflow security, Slither, dependency, secret scanning | Slither is opt-in and build-dependent |
| TypeScript/JavaScript service or tooling | Service application | Workflow security, Semgrep, CodeQL, dependency review, IaC | Current defaults are closest to this class |
| Terraform, Kubernetes, deployment repositories | Infrastructure | Workflow security, Trivy IaC, secrets, Scorecard | Runtime and cloud-policy coverage is project-specific |
| Several of the above in one repository | Composed path-scoped profiles | Detector emits one or more profiles per recognized component | Specialized evaluations are not all released yet |

## Detect Profiles Automatically

After checking out the repository, invoke
`filecoin-project/ff-sec-actions/actions/detect-filecoin-profile` at a reviewed
full commit SHA. The action reads repository files without executing project
code and exposes:

- `profiles-json` for path-aware evaluation routing;
- `result-file` for the complete evidence and selection reasons;
- `summary` for the readable component table; and
- `coverage-gaps-count` for recognized but unsupported components.

Every selected profile includes its component path, confidence, evidence file,
and reason. Unsupported components produce a warning and remain in the result
with no guessed profile. See the complete [profile-detection contract](../reference/profile-detection.md)
for copyable workflow YAML, inputs, outputs, supported signals, and limitations.

## Selection Rules

1. Choose based on security-relevant behavior, not the repository's primary
   language alone.
2. Compose profiles for monorepos instead of forcing one global choice.
3. Record unsupported components as coverage gaps.
4. Treat consensus-critical and funds-moving code as requiring human review
   even when automated evaluation completes.
5. Do not enable build-dependent analysis on untrusted PRs until its execution
   boundary is documented.
6. Review every coverage gap and the detector limitation before treating the
   selected profile set as complete.

## Next

- [Start a pilot](quickstart.md)
- [Review permissions](permissions-and-secrets.md)
- [Understand results](understand-results.md)
