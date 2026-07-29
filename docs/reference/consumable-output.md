# Consumable Output Contract

**Stability:** required pre-v1 release contract for every reusable evaluation
workflow and composite action.

**Owner:** Filecoin ecosystem security platform maintainers. The machine-readable
inventory is [`security/output-contract.json`](../../security/output-contract.json).

An evaluation is not consumable merely because a scanner returned findings.
Before an evaluation exits, a Consumer Engineer must be able to determine what
ran, what it found, where it found it, how to remediate it, why policy passed or
failed, and where durable evidence lives.

## Required Evaluation Surfaces

| Surface | Required content |
|---|---|
| Job summary | Tool/version, Completion Status, findings count/severity, Merge Gate reason, evaluated scope, coverage, and evidence artifact |
| Source annotations | Capped, escaped file/line annotations for SARIF findings; secret values remain redacted |
| Remediation | Rule guidance plus evaluation-specific next steps and safe suppression policy |
| Evaluation Result | Stable machine-readable completion, findings, gate, scope, coverage, and evidence identity |
| Raw evidence | Predictably named durable artifact containing complete SARIF or native output |
| Profile Conclusion | One row per evaluation mapping completion, findings, gate reason, scope, artifact, and evidence path |

Provider-native evaluations such as CodeQL and Dependency Review may use their
GitHub alert or pull-request surfaces, but the manifest must name that surface
and its remediation source. Inventory workflows such as SBOM generation must
name the durable artifact and its operational use.

## Finding Presentation

The Evaluation Adapter renders at most 20 findings by default to prevent noisy
or attacker-controlled output from overwhelming the run. Each rendered finding
contains severity, rule, repository path, line, scanner-provided message, and
available rule help. Secret-producing scanners must redact messages before the
adapter receives them; the shared Gitleaks invocation uses full redaction. The
complete result remains in the named raw-evidence artifact.

Blocking findings exit `1` only after the Evaluation Result, job summary, and
annotations are emitted. Operational or completion errors exit `2` with a
summary describing the next action. Advisory findings exit `0` without hiding
their locations or remediation.

For secret detection, credentials are always fully redacted. Remediation starts
with revocation or rotation, followed by source/history removal and access-log
review. Suppression is appropriate only for a verified false positive.

## Compatibility And Authority

Rendering requires no additional token permission, secret, network request, or
Consumer Project code execution. Artifact upload remains the responsibility of
the calling workflow. The same summary behavior applies on pull requests,
pushes, schedules, and manual runs; normal fork restrictions still apply.

Output names and Evaluation Result fields are pre-v1. Removing or renaming a
declared output, artifact, evaluation id, or summary field requires migration
guidance and a reviewed immutable pin advance.

Artifacts use the Consumer Project repository's configured GitHub Actions
retention unless a caller explicitly sets `retention-days`. Operators must set
repository retention long enough for their triage and audit requirements.

Low-level scanner invocation actions are developer building blocks rather than
standalone Consumer Project evaluations. Their consumable interface is an
explicit operational outcome plus a raw-evidence path, and the output contract
requires an owning normalized workflow to compose them with the Evaluation
Adapter before ecosystem release.

## Adding A New Evaluation

Before release, a Platform Maintainer must:

1. declare the workflow and action interfaces in
   [`security/output-contract.json`](../../security/output-contract.json);
2. use the shared Evaluation Adapter or document the provider-native surface;
3. supply remediation guidance and a stable raw-evidence artifact name;
4. declare the shared lifecycle suite, retain public `tool-outcome`, evidence,
   and blocking-policy wiring, and add tool-specific invocation fixtures where
   the shared adapter suite cannot exercise behavior;
5. run the output contract checks.

```bash
bash scripts/check-output-contract.sh
bash scripts/test-output-contract.sh
```

CI rejects any new reusable workflow or composite action that is absent from
the output contract inventory.

## Next

- [Evaluation Adapter](evaluation-adapter.md)
- [Evidence Bundle and Profile Conclusion](evidence-bundle.md)
- [Understand Evaluation Results](../consumers/understand-results.md)
