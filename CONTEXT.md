# Filecoin Ecosystem Security Evaluation

This context defines the shared language for centrally maintained security
evaluation that can be consumed by independent Filecoin ecosystem projects.

## Language

**Ecosystem Baseline**:
The secretless, low-privilege set of security evaluations that is safe and
useful for every supported project.
_Avoid_: Full pipeline, default scanners, one-size-fits-all workflow

**Security Profile**:
A versioned collection of evaluations and policy defaults for a project class,
such as Go nodes, Rust actors, Solidity contracts, or service applications.
_Avoid_: Preset, language toggle, scanner bundle

**Privileged Analysis**:
An optional evaluation that needs a secret, write permission, external service,
or other authority unavailable to the Ecosystem Baseline.
_Avoid_: Advanced scan, full mode

**Consumer Project**:
A Filecoin ecosystem repository that adopts an Ecosystem Baseline, Security
Profile, or Privileged Analysis maintained here.
_Avoid_: Client, downstream, target repo

**Consumer Engineer**:
A person adopting, configuring, interpreting, or upgrading security evaluation
inside a Consumer Project.
_Avoid_: User, customer, downstream developer

**Platform Maintainer**:
A person extending or releasing workflows, actions, profiles, prompts, schemas,
or documentation in the Control Repository.
_Avoid_: Developer, contributor, action author

**Rollout Operator**:
A person coordinating adoption, policy, exceptions, and health across multiple
Consumer Projects.
_Avoid_: Admin, security user, organization owner

**Evaluation Result**:
The normalized findings and evidence produced by one evaluation, together with
an explicit completion status.
_Avoid_: Scanner output, check result

**Completion Status**:
Whether an evaluation completed its declared scope, was incomplete, was
skipped by policy, or failed operationally; it is independent of finding
severity.
_Avoid_: Success, clean, no findings

**Merge Gate**:
A consumer-selected policy that converts Evaluation Results and Completion
Statuses into a merge-blocking decision.
_Avoid_: Blocking scanner, fail-on-error

**Evidence Bundle**:
The durable, machine-readable collection of normalized results, coverage
metadata, tool versions, and source references for one pipeline run.
_Avoid_: Artifact, logs, SARIF file

**Control Repository**:
This repository, which owns shared evaluation logic, Security Profiles,
release integrity, and compatibility contracts.
_Avoid_: Actions repo, central scripts
