# FOC Integrator Pack

**For:** Consumer Engineers building on Filecoin Onchain Cloud (FOC), and
Platform Maintainers changing or promoting FOC rules.

**Outcome:** integration mistakes that only matter on FOC and FEVM are reported
in the pull request, each with what breaks on Filecoin and how to fix it,
without executing Consumer Project code.

[`rules/foc-integrator.yml`](../../rules/foc-integrator.yml) is a versioned,
repository-owned Semgrep ruleset. The Ecosystem Baseline runs it as its own
evaluation, `semgrep-foc`, on every adoption: there is nothing to configure.
Its rules match only FOC interfaces, callbacks, SDK calls, and FEVM-specific
behavior, so on a repository that does not integrate FOC it completes with no
findings. Like every baseline rule, it is loaded from the same immutable commit
as the [`semgrep-scan` action](../../actions/semgrep-scan/action.yml) and never
from Consumer Project Semgrep configuration.

## Using The Pack

Adopt or advance the [Ecosystem Baseline](../consumers/ecosystem-baseline.md)
pin; `semgrep-foc` runs on the next pull request. On a pull request the summary
lists findings the change introduces first, so start there.

### Run It Before You Push

The rules are a single file at the commit your workflow pins. Scan with the same
digest-pinned Semgrep image the baseline uses (replace `<pinned-sha>` with the
SHA in your `ecosystem-baseline.yml@...` line):

```bash
curl -fsSL -o /tmp/foc-integrator.yml \
  https://raw.githubusercontent.com/filecoin-project/ff-sec-actions/<pinned-sha>/rules/foc-integrator.yml
docker run --rm -v "$PWD:/src" -v /tmp/foc-integrator.yml:/rules/foc-integrator.yml:ro -w /src \
  semgrep/semgrep:1.93.0@sha256:f35c7891e2030110a84a721fdd556ce8f3da6e7e69d7fab1d3660ae1bb334474 \
  semgrep scan --metrics=off --disable-version-check --config /rules/foc-integrator.yml .
```

Local rule IDs carry a path prefix such as `rules.foc.solidity.hardcoded-gas`;
the part from `foc.` onward is the rule in the table below.

### See A Finding And Its Fix

Each rule has a paired example: the
[`positive/`](../../test/fixtures/foc-integrator/positive/) file marks every
line the rule reports with `// ruleid:`, and the same-named
[`clean/`](../../test/fixtures/foc-integrator/clean/) file shows the fixed
pattern the rule accepts. For example,
[`positive/rail-terminated-can-revert.sol`](../../test/fixtures/foc-integrator/positive/rail-terminated-can-revert.sol)
reverts and makes an unguarded external call in `railTerminated`;
[`clean/rail-terminated-can-revert.sol`](../../test/fixtures/foc-integrator/clean/rail-terminated-can-revert.sol)
keeps only the caller check, wraps the call in `try`/`catch`, and emits events.

### Dismiss A Verified False Positive

Fix the code when the finding applies. When your design intentionally does what
the rule reports (for example, a service contract that must block payer-initiated
rail termination), suppress that one line with the rule ID and a reason:

```solidity
// Intentional: only the service may terminate rails; see docs/payments.md.
require(terminator == serviceProvider, "service-initiated only"); // nosemgrep: foc.solidity.rail-terminated-can-revert
```

Name the rule rather than writing a bare `nosemgrep`, which hides every rule on
that line, and never use `.semgrepignore` to skip contract or SDK source.
Suppressions are not yet listed in results (see
[Known Limitations](#known-limitations)), so reviewers see them only in the
diff. If a rule is wrong for a common FOC pattern, report it to the Control
Repository instead so the rule can be narrowed for everyone.

## Rules

| Rule | What breaks on FOC | Fix |
|---|---|---|
| `foc.solidity.callback-missing-caller-check` | A `PDPListener` callback (`dataSetCreated`, `dataSetDeleted`, `piecesAdded`, `piecesScheduledRemove`, `possessionProven`, `nextProvingPeriod`, `storageProviderChanged`) or `IValidator` callback (`validatePayment`, `railTerminated`) that never checks `msg.sender` can be called by anyone with forged proof, data-set, or rail events, and payments follow those events. | Require `msg.sender` to be the stored PDPVerifier or Filecoin Pay address, or apply a caller-restricting modifier. |
| `foc.solidity.rail-terminated-can-revert` | Filecoin Pay calls `railTerminated` while terminating a rail. A `require`, `revert`, `assert`, or unguarded external call there blocks termination and traps the payer's funds. | Never revert in `railTerminated`: move checks into `validatePayment`, wrap external calls in `try`/`catch`, and emit events. A caller check on `msg.sender` is allowed. |
| `foc.solidity.transfer-send-reentrancy` | FEVM has no 2300 gas stipend, so `transfer` and `send` forward enough gas for the recipient to re-enter. They are not reentrancy protection on Filecoin. | Update state first, add a reentrancy guard, and use `call` with a checked result. |
| `foc.solidity.hardcoded-gas` | FEVM gas costs differ from Ethereum and change at network upgrades, so `{gas: <literal>}` or `gasleft()` compared with a literal can fail on Filecoin. | Forward available gas or make the amount configurable. |
| `foc.solidity.block-randomness` | `block.prevrandao` and `block.difficulty` are not unbiasable on Filecoin, and `blockhash` returns an earlier block's hash across null rounds. | Use drand randomness from the Filecoin randomness precompile, or commit-reveal. |
| `foc.typescript.browser-exposed-private-key` | A key read from `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`, or `PUBLIC_*` (through `process.env` or `import.meta.env`) and passed to `privateKeyToAccount`, `new Wallet`, or `Synapse.create({ privateKey })` is bundled into client code, exposing the wallet that pays for storage. | Sign server-side from a non-public variable, use the user's wallet, or use a scoped Synapse session key. |
| `foc.typescript.unlimited-operator-allowance` | An explicit `maxUint256`/`MaxUint256`/`2n ** 256n - 1n` rate or lockup allowance in `approveService`, `depositWithPermitAndApproveOperator`, or `setOperatorApproval` removes the cap on what the operator can charge or lock. | Set bounded allowances sized to the application and re-approve when they change. |

Each finding's summary row and annotation carry this impact and fix with links
to the [Filecoin Pay integration guide](https://github.com/FilOzone/filecoin-pay/blob/main/docs/integration.md),
the [PDP verifier](https://github.com/FilOzone/pdp/blob/main/src/PDPVerifier.sol),
[FEVM differences from Ethereum](https://docs.filecoin.io/smart-contracts/filecoin-evm-runtime/difference-with-ethereum),
or the [Synapse SDK](https://github.com/FilOzone/synapse-sdk).

The rules favor precision: a callback with any modifier is treated as
caller-checked, and `approveService()` with omitted allowances (which the SDK
defaults to unlimited) is not reported. A clean result means only that these
rules completed over the reported scope.

## Wallet-Key Secrets

Secret scanning adds a repository-owned
[`filecoin-wallet-key-export`](../../rules/gitleaks-filecoin.toml) rule for
hex-encoded `lotus wallet export` output (`secp256k1`, `bls`, and `delegated`
keys) on top of the Gitleaks defaults. It follows the consumer-selected
`secrets-blocking` gate. When the Consumer Project has its own `.gitleaks.toml`,
that file is used instead and the secrets result records that the Filecoin rule
was not applied.

## Advisory Policy

Every FOC rule is advisory in this release. The `semgrep-foc` finding gate is
fixed to advisory and ignores `static-analysis-blocking`. Completion still
counts: a failed or missing `semgrep-foc` result fails `Profile Conclusion`
under the default `require-complete: true`.

## Promotion To Blocking

A rule becomes eligible to block merges only when all of these hold:

1. It has a positive fixture under
   [`test/fixtures/foc-integrator/positive/`](../../test/fixtures/foc-integrator/positive/)
   that it detects on the annotated lines, and a clean fixture under
   [`clean/`](../../test/fixtures/foc-integrator/clean/) that it does not.
2. It has an entry in
   [`rules/foc-integrator-precision.json`](../../rules/foc-integrator-precision.json)
   from a scan of the FilOzone reference repositories (`filecoin-services`,
   `pdp`, `filecoin-pay`, `synapse-sdk`) at pinned commits, with every finding
   triaged as a true or false positive.
3. The promotion is decided in a roadmap task (FILE-01 or VERIFY-01) that
   records the accepted precision.

`bash scripts/test-foc-integrator.sh` enforces the first two for every rule.

## Known Limitations

- Semgrep honors `.semgrepignore` and inline `nosemgrep` in the scanned
  repository, as described in the
  [baseline static rules](ecosystem-baseline-rules.md). Reporting those
  exclusions is BASE-01 work.
- The pinned Semgrep 1.93.0 grammar only partially parses some modern Solidity
  and TypeScript (for example `assembly ("memory-safe")` blocks and named
  mapping parameters); rules may miss findings in those files, and the result
  does not yet list them. The precision record names the affected reference
  files.
- The pack does not cover FilOzone core-protocol checks (storage layout,
  selector collisions, settlement invariants), calibration and mainnet
  configuration mix-ups, or `CALLCODE` and `SELFDESTRUCT` use.

## Next

- [Ecosystem Baseline static rules](ecosystem-baseline-rules.md)
- [Consumable output contract](consumable-output.md)
- [Filecoin Security Profile detection](profile-detection.md)
