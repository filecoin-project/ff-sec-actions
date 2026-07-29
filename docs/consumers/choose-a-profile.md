# Choose A Security Profile

**For:** a Consumer Engineer deciding which evaluations apply to a project.

**Outcome:** a documented profile choice with known coverage gaps.

Security Profiles are part of the target architecture and are not yet released.
Until the `profile-taxonomy` decision is resolved, use this table only to plan a
pilot.

| Project signals | Candidate profile | Current useful evaluations | Important gap |
|---|---|---|---|
| Lotus, Venus, or other Go node code | Go node | Workflow security, Semgrep, CodeQL for Go, dependency and secret scanning | No released Filecoin node rule pack |
| Builtin actors, ref-fvm, or Rust/WASM | Rust/FVM actor | Workflow security, dependency, secret, generic static analysis | No released actor-invariant profile |
| Solidity contracts targeting FEVM | Solidity/FEVM | Workflow security, Slither, dependency, secret scanning | Slither is opt-in and build-dependent |
| TypeScript/JavaScript service or tooling | Service application | Workflow security, Semgrep, CodeQL, dependency review, IaC | Current defaults are closest to this class |
| Terraform, Kubernetes, deployment repositories | Infrastructure | Workflow security, Trivy IaC, secrets, Scorecard | Runtime and cloud-policy coverage is project-specific |
| Several of the above in one repository | Composed monorepo | Run relevant evaluations by path | Profile composition is not yet implemented |

## Selection Rules

1. Choose based on security-relevant behavior, not the repository's primary
   language alone.
2. Compose profiles for monorepos instead of forcing one global choice.
3. Record unsupported components as coverage gaps.
4. Treat consensus-critical and funds-moving code as requiring human review
   even when automated evaluation completes.
5. Do not enable build-dependent analysis on untrusted PRs until its execution
   boundary is documented.

## Next

- [Start a pilot](quickstart.md)
- [Review permissions](permissions-and-secrets.md)
- [Understand results](understand-results.md)
