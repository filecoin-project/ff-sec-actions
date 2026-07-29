# Ecosystem Baseline Static Rules

**For:** Consumer Engineers evaluating default static coverage and Platform
Maintainers changing shared rules.

**Outcome:** a small, versioned, reviewable ruleset that runs without fetching
mutable registry configuration or executing Consumer Project code.

[`rules/ecosystem-baseline.yml`](../../rules/ecosystem-baseline.yml) contains
high-signal checks for:

- JavaScript/TypeScript dynamic shell command construction;
- Go TLS verification disablement;
- Rust dynamic shell command construction;
- Solidity `tx.origin` authorization;
- Dockerfile remote-response piping into a shell.

These rules complement, rather than replace, workflow security, Gitleaks,
recursive Trivy manifest/lockfile analysis, and Trivy IaC evaluation. A clean
result means only that the declared rules completed over the reported scope.

The rules are loaded from the same immutable repository commit as the
[`semgrep-scan` action](../../actions/semgrep-scan/action.yml). The baseline does
not use Semgrep registry aliases or Consumer Project configuration. Projects
may run additional rules separately, but those results are not part of the
versioned Ecosystem Baseline conclusion.

## Next

- [Evaluation adapter](evaluation-adapter.md)
- [Evidence Bundle](evidence-bundle.md)
