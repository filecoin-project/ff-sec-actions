# Proposal

## Why

The Ecosystem Baseline's static analysis is generic: five conservative rules, none of them about Filecoin. Third-party builders on Filecoin Onchain Cloud (FOC) write service contracts against Filecoin Pay and PDP and build apps on the Synapse SDK. They make mistakes that generic tools miss or get wrong:

- An `IValidator.railTerminated` that reverts. The Filecoin Pay integration guide says it must never revert, because a revert takes away the payer's way out and traps funds.
- `PDPListener` callbacks with no `msg.sender` check. Payments follow proof events, so anyone can fake them.
- `.transfer`/`.send` relied on for reentrancy safety. FEVM has no 2300 gas stipend.
- A funded private key shipped to the browser.

The current output also lists every finding, old and new, in a long report, so a Consumer Engineer can't see quickly what their pull request changed.

## What Changes

- **Roadmap:** add task **FOC-01, "Ship the FOC integrator pack"**, immediately before BASE-01. Its only dependency is EVAL-03. Later tasks are renumbered. Remove the empty `complete-ecosystem-baseline` change scaffold so that FOC-01 can hold the single in-progress slot. BASE-01 stays unclaimed and becomes the next task.
- **New FOC integrator pack:** a versioned, repository-owned Semgrep ruleset, `rules/foc-integrator.yml`, with seven rules:
  - Solidity:
    - FOC callbacks with no caller check
    - `railTerminated` paths that can revert
    - `.transfer`/`.send` used as reentrancy protection
    - Hard-coded gas
    - `block.prevrandao`/`blockhash` used as randomness
  - TypeScript:
    - A browser-exposed private key reaching Synapse or a signer
    - Unlimited operator allowances

  Every finding explains what happens on FOC and how to fix it, and links to the FOC documentation.
- **New baseline evaluation:** the pack runs as a sixth Ecosystem Baseline evaluation, `semgrep-foc`, inside the existing static-analysis job. It is always on, and its rules match only FOC-specific names, so it stays silent on other repositories. In v1 its finding gate is fixed to advisory. The pack is FOC's add-on to every profile, not a new Security Profile.
- **Secret scanning:** gains a repository-owned rule for exported Filecoin wallet keys. When a Consumer Project supplies its own Gitleaks configuration, the result reports that the Filecoin rule was not applied.
- **New findings first:** on pull requests, Semgrep evaluations mark each finding as new or existing relative to the base commit. Summaries lead with the findings the pull request introduces and fold existing ones into a count. All findings stay in the raw evidence, and gate semantics do not change.
- **Profile detection:** reports an `foc` add-on, with path-scoped evidence, when it finds the Synapse SDK or Solidity imports of Filecoin Pay or PDP interfaces. Detection only reports and does not choose what runs.
- **Path to blocking:** a rule can become eligible to block only when it has a positive fixture, a clean fixture, and a precision measurement recorded against the FilOzone repositories (`filecoin-services`, `pdp`, `filecoin-pay`, `synapse-sdk`). This change records the first measurement. Promotion itself is out of scope.

Out of scope:
- Consumer `.semgrepignore` and `nosemgrep` exclusions are still unreported until BASE-01, which is acceptable while the pack is advisory.
- FilOzone core-protocol checks: storage layout, selector collisions, invariants.
- Calibration/mainnet mix-ups.
- `CALLCODE` and `SELFDESTRUCT`.

## Capabilities

### New Capabilities
- `foc-integrator-pack`: the FOC rule pack and its rules, explanations, advisory policy, fixtures, precision record, and Filecoin wallet-key secret rule.

### Modified Capabilities
- `ecosystem-baseline`: six evaluations instead of five, and static rules now include the FOC pack.
- `consumable-output`: finding presentation leads with new findings when baseline state is available.
- `profile-detection`: detection reports catalog-defined add-ons, starting with `foc`, separately from profiles.

## Impact

- `roadmap/state.json`: new FOC-01, renumbered orders, and FOC-01 linked to this change. The `openspec/changes/complete-ecosystem-baseline/` scaffold is removed.
- New files:
  - `rules/foc-integrator.yml`
  - `rules/gitleaks-filecoin.toml`
  - `rules/foc-integrator-precision.json`
  - `test/fixtures/foc-integrator/`
  - `scripts/test-foc-integrator.sh`
  - `scripts/measure-foc-precision.sh`
- `actions/semgrep-scan/`: a second rules config, plus optional baseline-commit classification.
- `actions/evaluation-adapter/`: new-versus-existing rendering.
- `actions/gitleaks-scan/`: Filecoin rule config selection.
- `actions/detect-filecoin-profile/` and `profiles/filecoin-project-profiles.json`: the `foc` add-on.
- `.github/workflows/sec-semgrep.yml`:
  - Full-history checkout on pull requests.
  - `semgrep-foc` result.
- `.github/workflows/ecosystem-baseline.yml` and `security-pipeline.yml`: the required evaluation list.
- `security/output-contract.json`, the release graph, and pins: the new evaluation and updated action SHAs.
- Docs:
  - `docs/reference/ecosystem-baseline-rules.md`
  - `docs/consumers/understand-results.md`
  - `docs/reference/profile-detection.md`
  - A new `docs/reference/foc-integrator-pack.md`
- Consumers: no new input. Adopting the new baseline pin adds one advisory evaluation and requires no configuration. Branch protection still points at `Profile Conclusion`.
