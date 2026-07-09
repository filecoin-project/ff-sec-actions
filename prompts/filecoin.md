# Domain context: Filecoin

The code under review belongs to the Filecoin ecosystem. Generic web3 and
static-analysis tooling lacks this context; you must apply it. Identify which
layer the diff touches and use the matching sections below.

## Ecosystem map — identify the layer first

- **Lotus / Venus / Forest** (Go / Go / Rust): full node implementations —
  chain sync, mempool, state computation, consensus (Expected Consensus + F3
  finality), JSON-RPC API, wallet, libp2p/gossipsub networking.
- **builtin-actors** (Rust → WASM): the on-chain "system contracts" (miner,
  market, power, reward, verifreg, multisig, paych, init, cron, EVM/EAM/
  ethaccount for FEVM). Executed by the FVM. Bugs here are consensus bugs.
- **ref-fvm** (Rust): the Filecoin Virtual Machine — WASM execution, gas
  accounting, syscalls, state access. The host boundary between attacker bytes
  and node internals.
- **go-state-types / filecoin-ffi**: shared state schemas, CBOR codegen, and
  the Rust proofs bridge used by Lotus.
- **FEVM contracts** (Solidity): user contracts on Filecoin's EVM runtime —
  Ethereum-like but with important semantic differences (below).
- **Storage-provider stack** (Boost, Curio, droplet): deal-making, sealing
  pipelines, proving; off-chain but funds- and slashing-relevant.

## Non-negotiable invariants (consensus-critical code)

Anything executed during state computation (actors, FVM, Lotus state manager)
must be **bit-for-bit deterministic across all nodes**:

- No map iteration order dependence (Go `map` ranging that affects state or
  gas), no floats in state math, no wall-clock time, no local randomness, no
  locale/environment-dependent behavior, no non-canonical serialization.
- Randomness comes only from the drand beacon / VRF tickets, fetched at an
  explicit epoch with the correct **domain separation tag (DST)** and lookback.
  Wrong DST or wrong lookback epoch is a critical finding.
- Gas charged must be identical across nodes: any new syscall, state read, or
  loop in actor/FVM code must have deterministic, input-bounded cost.
- State mutations must go through the actor's transaction pattern
  (`rt.transaction` / `state.save` equivalents). Reading state, mutating a
  copy, and forgetting to flush — or flushing twice — corrupts the state root.
- HAMT/AMT usage: constructed with the protocol-specified bitwidth; every
  mutation followed by a flush; iteration over user-growable collections must
  be bounded (cron and batch operations especially).
- Any behavior change in actors or state computation is a **network-breaking
  change requiring a FIP and a network upgrade**. Flag "innocent" refactors
  that alter observable state, gas, or exit codes without version gating
  (`NetworkVersion` / actors version checks).

## Actor-safety bug classes (builtin-actors, Rust)

- **Abort vs panic:** actors must fail via exit codes (`abort` /
  `require_*`), never panic/unwrap/expect on reachable paths — a panic in a
  cron-invoked actor can wedge the chain. `unwrap()` on decoded user params is
  a finding.
- **Attacker-controlled params:** every exported method's params arrive as
  attacker CBOR from the mempool. Look for missing bounds checks on vector
  lengths, nested structures that bypass validation, addresses not resolved to
  ID form before use, and decode-then-trust patterns.
- **Re-entrancy via `send`:** an actor calling another actor (including value
  transfers) can be re-entered before its state transaction completes.
  Check-effects-interactions applies on Filecoin too. Sends can also fail —
  unchecked send results that should roll back state are findings.
- **Token math:** `TokenAmount` / `BigInt` do not overflow but can go
  negative — verify subtraction paths guard against negative balances,
  division-by-zero, and rounding direction (who keeps the dust matters for
  pledge, penalties, and deal payments).
- **Epoch math:** `ChainEpoch` arithmetic around proving deadlines, precommit
  expiry, deal start/end, and vesting schedules is a classic bug source.
  Watch off-by-one at deadline open/close boundaries, null rounds (epochs with
  no blocks), and 30-second epoch assumptions hardcoded as constants.
- **Miner lifecycle:** sector precommit → prove-commit windows, fault/recovery
  declaration cutoffs, termination penalties, expiration queues (BitField
  operations), and partition/deadline bookkeeping. Any change here should be
  cross-checked against the miner actor's queue invariants: a sector must never
  be double-counted in power or live in two queues.
- **Exit codes are API:** changing an exit code changes consensus and breaks
  callers that match on it.

## FEVM / Solidity specifics

Ethereum knowledge mostly applies, plus these differences:

- Addresses: f0 (ID), f1/f3 (key), f2 (actor), f4/0x (delegated/EVM). ID
  addresses are reassignable-looking small integers — converting between 0x and
  f0 forms and using an ID address before the actor is stable can misroute
  funds. Contracts comparing `msg.sender` against precomputed addresses need
  care with the f4↔0x mapping.
- Native calls to builtin actors go through precompiles / `call_actor`; their
  failure semantics (exit codes) differ from EVM reverts — check translation.
- `block.timestamp`/`block.number` map to 30s epochs; `prevrandao` maps to the
  drand-derived randomness; finality is much longer than Ethereum (F3 has
  shortened it, but code assuming ~12s blocks or fast finality is wrong).
- Gas is Filecoin gas under the hood; hardcoded Ethereum gas constants
  (`2300` stipend assumptions, `transfer()` usage) can behave differently.
- Standard EVM issues still apply: re-entrancy, unchecked call returns,
  delegatecall storage collisions, oracle manipulation, access control.

## Node-level bug classes (Lotus/Forest/Venus, Go/Rust)

- **Liveness:** the highest-value bug class in node code — a single message,
  gossip payload, or RPC call must never wedge the node. Look for:
  re-entrancy on singleflight/memoization state, lock-ordering inversions,
  `mutex` held across channel sends or network I/O, validate-**after**-
  expensive-work orderings on peer-controlled input, and unbounded queues.
- **Peer-controlled input:** anything from libp2p, gossipsub, mempool, or
  chain-exchange is attacker input — decode limits, epoch/height sanity checks
  *before* expensive work (e.g. a future-epoch field triggering huge state
  computation), and per-peer rate/resource limits.
- Goroutine and context hygiene: leaked goroutines on error paths, missing
  `ctx` cancellation on long state computations, `defer` in loops.
- JSON-RPC: methods exposed on the wrong permission tier (read vs sign vs
  admin), untrusted params reaching state computation or the wallet.

## Storage-provider stack

- Deal funds and collateral flows: escrow accounting in the market actor,
  deal-publish validation, off-chain acceptance logic that trusts client input.
- Sealing/proving pipeline: window PoSt scheduling errors → faults →
  penalties; anything that could cause a missed proving deadline is
  effectively a funds-loss bug for SPs.

## Severity calibration for this domain

- Consensus divergence, chain halt, remote node crash, loss/theft of funds,
  minting/supply errors → `critical`.
- Missed slashing, incorrect penalties, state bloat vectors, single-node DoS
  requiring effort, permission-tier mistakes → `high`.
- Wrong gas pricing without divergence, recoverable SP fund exposure,
  edge-case epoch math → typically `medium`+ depending on reachability.

When the diff is plain application/tooling code with no protocol relevance,
say so in the summary and review it as ordinary software — do not invent
Filecoin findings where the domain does not apply.
