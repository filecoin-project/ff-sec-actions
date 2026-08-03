# Filecoin Security Profile Detection

**Stability:** pre-v1 composite-action contract

**Trust tier:** `ecosystem-baseline`; local, secretless, and non-executing

The detector inspects repository structure, manifests, declared dependencies,
Filecoin imports, and infrastructure configuration. It does not install
dependencies, invoke compilers, load repository configuration, or execute
Consumer Project code.

## Consumer Usage

Check out the Consumer Project without persisted credentials, then invoke the
detector at a reviewed full commit SHA:

```yaml
permissions:
  contents: read

steps:
  - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
    with:
      persist-credentials: false

  - name: Detect Filecoin Security Profiles
    id: profiles
    uses: filecoin-project/ff-sec-actions/actions/detect-filecoin-profile@<reviewed-full-commit-sha>
    with:
      result-file: ${{ runner.temp }}/profile-detection.json
      summary-file: ${{ runner.temp }}/profile-detection-summary.md

  - name: Upload profile evidence
    uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7
    with:
      name: filecoin-profile-detection
      path: |
        ${{ steps.profiles.outputs.result-file }}
        ${{ steps.profiles.outputs.summary }}
      if-no-files-found: error
```

Replace the placeholder only with a reviewed commit that contains this action.
The Control Repository remains pre-v1 and does not publish a moving `v1` tag.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `repository-path` | `.` | Checked-out repository path treated as untrusted data |
| `result-file` | Runner temporary directory | Machine-readable result destination |
| `summary-file` | Runner temporary directory | Readable component/profile table destination |

## Outputs

| Output | Meaning |
|---|---|
| `result-file` | Path to the complete JSON result |
| `summary` | Path to the Markdown component/profile table |
| `profiles-json` | Compact array of selected profile IDs and path scopes |
| `component-count` | Number of recognized components, including unsupported ones |
| `coverage-gaps-count` | Number of recognized components with no supported profile |

The action also appends the table to the GitHub job summary and emits one
warning annotation per unsupported component.

## Detection Result

The version `1` document contains:

- detector name and version;
- explicit completion status and target;
- components with path, classification status, selected profiles, confidence,
  evidence paths, and selection reasons;
- selected profiles grouped by their component paths;
- included paths, coverage gaps, and known limitations.

Consumers should route later evaluations from `profiles-json`, but preserve and
upload `result-file` as the authoritative evidence. A zero
`coverage-gaps-count` does not prove every directory was understood: the result
always records that directories without recognized project or infrastructure
markers may require manual selection.

## Supported Profiles

| Profile | Current high-value signals |
|---|---|
| `go-node` | Lotus, Venus, or Filecoin state dependencies in `go.mod` |
| `fvm-actor` | FVM SDK, shared runtime, or actor runtime dependencies in `Cargo.toml` |
| `fevm-contract` | Filecoin Solidity libraries, actor APIs, or precompile addresses |
| `service` | Recognized network service frameworks or runtime entry points |
| `infrastructure` | Terraform, Kubernetes workload, or container configuration |
| `storage-application` | Recognized Filecoin or IPFS storage client dependencies |
| `storage-provider-infrastructure` | Lotus Miner, Boost, Curio, Venus Sealer, privileged API, or proof-cache configuration |

The machine-readable source is
[`profiles/filecoin-project-profiles.json`](../../profiles/filecoin-project-profiles.json).
Signals are intentionally conservative. A recognized manifest without a
supported match becomes an `unsupported` component rather than a guessed
profile.

## Maintainer Verification

```bash
bash scripts/test-detect-filecoin-profile.sh
bash scripts/check-output-contract.sh
bash scripts/check-execution-trust.sh
```

New signals require a planted fixture, a stable reason string, a profile
catalog update when applicable, and proof that unsupported components remain
visible.

## Next

- [Choose a Security Profile](../consumers/choose-a-profile.md)
- [Consumable output contract](consumable-output.md)
- [Execution trust tiers](execution-trust.md)
