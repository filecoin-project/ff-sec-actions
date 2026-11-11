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

Filecoin Onchain Cloud integration rules live in a separate pack,
[`rules/foc-integrator.yml`](../../rules/foc-integrator.yml), reported as its own
advisory `semgrep-foc` evaluation. See the [FOC integrator pack](foc-integrator-pack.md).

These rules complement, rather than replace, workflow security, Gitleaks,
recursive Trivy manifest/lockfile analysis, and Trivy IaC evaluation. A clean
result means only that the declared rules completed over the reported scope.

The rules are loaded from the same immutable repository commit as the
[`semgrep-scan` action](../../actions/semgrep-scan/action.yml). The baseline does
not use Semgrep registry aliases or rules from a Consumer Project Semgrep
configuration file. Projects may run additional rules separately, but those
results are not part of the versioned Ecosystem Baseline conclusion.

> **Known limitation:** Semgrep still honors a `.semgrepignore` file and inline
> `nosemgrep` comments in the scanned repository, including ones added by a
> fork pull request. They can exclude files or findings from this evaluation
> while it still reports `complete`. Review changes to `.semgrepignore` and new
> `nosemgrep` comments as security-relevant until the baseline removes this
> consumer control.

## Next

- [FOC integrator pack](foc-integrator-pack.md)
- [Evaluation adapter](evaluation-adapter.md)
- [Evidence Bundle](evidence-bundle.md)
