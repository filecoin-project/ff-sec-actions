# Spec Delta

## Purpose

Detects integration mistakes specific to Filecoin Onchain Cloud (Filecoin Pay, PDP, FEVM runtime differences, and the Synapse SDK) in Consumer Project source without executing it, and explains each finding in FOC terms with a concrete fix.

## ADDED Requirements

### Requirement: The pack is a versioned, repository-owned ruleset
The FOC integrator pack SHALL load rules only from a repository-owned file at the same immutable commit as its scanner action. It SHALL NOT use registry rules or any Consumer Project configuration. It SHALL run on every Ecosystem Baseline adoption without consumer input.

#### Scenario: Consumer repository contains a Semgrep config
- **WHEN** a Consumer Project contains its own Semgrep configuration that adds a rule
- **THEN** the FOC evaluation runs only the versioned pack rules and reports no consumer-defined rule

### Requirement: Solidity integration rules
The pack SHALL detect, in Solidity:
- `PDPListener` or `IValidator` callbacks whose body and modifiers never reference `msg.sender`.
- `railTerminated` implementations containing `require`, `revert`, or an external call outside `try`/`catch`.
- `.transfer`/`.send` used for value transfer.
- Literal gas amounts in call options or `gasleft()` comparisons.
- `block.prevrandao`, `block.difficulty`, or `blockhash` used as a value source.

#### Scenario: Listener callback without caller check
- **WHEN** a contract implements `possessionProven` from `PDPListener` and never checks `msg.sender`
- **THEN** the pack reports one finding at that function

#### Scenario: Listener callback with caller check
- **WHEN** the same callback requires `msg.sender` to equal the stored verifier address
- **THEN** the pack reports no finding for it

#### Scenario: Reverting termination hook
- **WHEN** `railTerminated` contains a `require` statement
- **THEN** the pack reports a finding explaining that the revert blocks rail termination

### Requirement: TypeScript Synapse integration rules
The pack SHALL detect, in JavaScript and TypeScript, a private key read from a browser-exposed environment variable (`NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`, or `PUBLIC_*`, through `process.env` or `import.meta.env`) that reaches a Synapse or wallet constructor. It SHALL also detect operator rate or lockup allowances explicitly set to the maximum `uint256` value.

#### Scenario: Browser-exposed key
- **WHEN** a module passes `process.env.NEXT_PUBLIC_PRIVATE_KEY` to a Synapse or wallet constructor
- **THEN** the pack reports one finding at that call

#### Scenario: Server-only key
- **WHEN** a module passes a non-public environment variable to the same constructor
- **THEN** the pack reports no finding for it

### Requirement: Rules stay silent on non-FOC code
Each pack rule SHALL match only FOC-specific interfaces, callbacks, SDK imports, or FEVM-specific behavior. The pack SHALL report no finding on the Ecosystem Baseline's existing cross-language fixture or on a clean FOC fixture.

#### Scenario: Repository without FOC
- **WHEN** the pack scans a repository with no FOC interfaces or Synapse SDK usage and no FEVM value-transfer, gas, or randomness patterns
- **THEN** the FOC evaluation completes with zero findings

### Requirement: Every finding explains the FOC impact and the fix
Each pack rule SHALL carry a message stating what happens on FOC if the pattern ships, a concrete fix, and a link to the FOC, Filecoin Pay, PDP, or FEVM documentation. The finding table and annotations SHALL show this guidance.

#### Scenario: Finding guidance rendered
- **WHEN** the FOC evaluation reports a `railTerminated` finding
- **THEN** the summary row includes the impact, the fix, and a documentation link

### Requirement: FOC findings are advisory in this release
The FOC evaluation's finding gate SHALL be advisory regardless of consumer inputs. Completion SHALL still count toward `require-complete`, so a failed FOC scan fails the profile under default policy.

#### Scenario: Consumer enables static-analysis blocking
- **WHEN** a Consumer Project sets `static-analysis-blocking: true` and the FOC evaluation reports findings
- **THEN** the FOC evaluation's gate passes as advisory and the findings remain in the summary and Evidence Bundle

#### Scenario: FOC scan fails operationally
- **WHEN** the FOC scan errors under default policy
- **THEN** `Profile Conclusion` fails

### Requirement: Every rule is proven by paired fixtures
Each pack rule SHALL have a positive fixture it must detect and a clean fixture it must not detect. The pack test SHALL fail if any fixture file is not scanned, any rule misses its positive fixture, or any rule fires on a clean fixture.

#### Scenario: Rule regresses to silence
- **WHEN** a rule change stops detecting its positive fixture
- **THEN** the pack test fails naming that rule

#### Scenario: Rule becomes noisy
- **WHEN** a rule change fires on its clean fixture
- **THEN** the pack test fails naming that rule and file

### Requirement: Rule precision is recorded against the reference corpus
A versioned precision record SHALL list, per rule, the reference repositories and commits scanned, the finding count, and each finding's triage as true or false positive. A rule SHALL NOT be eligible to block without a record entry.

#### Scenario: Rule without measurement
- **WHEN** the precision record has no entry for a pack rule
- **THEN** the pack test fails

### Requirement: Committed Filecoin wallet key exports are secrets
Secret scanning SHALL detect hex-encoded Filecoin wallet key exports (`secp256k1`, `bls`, or `delegated` key types) using a repository-owned rule, in addition to the default rules, redacted like any other secret.

#### Scenario: Exported wallet key committed
- **WHEN** a commit in scope adds a hex-encoded `secp256k1` wallet export
- **THEN** secret scanning reports a finding and no output contains the key value

#### Scenario: Consumer supplies its own Gitleaks config
- **WHEN** the Consumer Project has a `.gitleaks.toml`
- **THEN** that config is used and the secrets result records a limitation that the Filecoin wallet-key rule was not applied
