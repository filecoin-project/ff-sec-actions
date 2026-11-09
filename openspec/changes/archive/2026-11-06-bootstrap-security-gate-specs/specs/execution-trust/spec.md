# Spec Delta

## Purpose

Defines which authority each workflow and action surface may hold while it inspects or executes Consumer Project content, so untrusted repository data can never reach secrets, write tokens, or OIDC.

## ADDED Requirements

### Requirement: Every surface is classified into one trust tier
Every workflow, example, and action metadata file SHALL be recorded in the machine-readable execution-trust inventory with a current tier and a release-eligible target tier. The inventory's recorded behavior flags SHALL match the source. A surface classified `legacy-mixed` SHALL NOT be release-eligible.

#### Scenario: Unclassified surface is rejected
- **WHEN** a workflow, example, or action is added without an inventory entry
- **THEN** the execution-trust check fails and names the unclassified path

#### Scenario: Recorded behavior drifts from source
- **WHEN** a surface's source gains a write permission, execution marker, or cache that its inventory entry does not record
- **THEN** the execution-trust check fails and names the mismatched field

#### Scenario: Human-readable contract omits a tier or surface
- **WHEN** the reference page does not name a declared tier or classified surface
- **THEN** the execution-trust check fails

### Requirement: Ecosystem Baseline inspects but never executes project behavior
A surface in the `ecosystem-baseline` tier SHALL treat Consumer Project content as data only. It SHALL NOT run package installation, lifecycle hooks, build configuration, compilers, project-local actions, or shell steps that invoke project-controlled behavior.

#### Scenario: Shell step added to a baseline workflow
- **WHEN** a workflow declared in the baseline no-execution policy contains a shell execution step
- **THEN** the baseline no-execution check fails

#### Scenario: Package-manager input exposed
- **WHEN** a baseline workflow exposes an input that would run a project package manager
- **THEN** the baseline no-execution check fails

#### Scenario: Unreviewed action used in a baseline workflow
- **WHEN** a baseline workflow uses an action that differs from the reviewed baseline policy
- **THEN** the baseline no-execution check fails

### Requirement: Jobs declare the narrowest explicit permissions
Every job SHALL declare its permissions explicitly. Its authority SHALL match the reviewed per-job workflow policy. Write authority SHALL be limited to `pull-requests: write` for optional pull-request publication, `security-events: write` for SARIF publication, and `id-token: write` for OpenSSF Scorecard publication outside pull-request execution.

#### Scenario: Implicit permissions
- **WHEN** a job omits an explicit permissions block
- **THEN** the workflow-security check fails

#### Scenario: Authority differs from reviewed policy
- **WHEN** a job requests a permission that the reviewed workflow policy does not record for it
- **THEN** the workflow-security check fails

### Requirement: Checkout never persists credentials
Every job that checks out repository content SHALL set `persist-credentials: false`.

#### Scenario: Persisted checkout credential
- **WHEN** a checkout step omits `persist-credentials: false`
- **THEN** the workflow-security check fails

### Requirement: Execution of project behavior never holds authority
A job that executes Consumer Project-controlled behavior SHALL NOT receive secrets, write permissions, or OIDC authority. A publisher SHALL NOT check out or execute untrusted content and SHALL treat incoming artifacts, caches, and scanner output as attacker-controlled evidence.

#### Scenario: Release-allowed tier violates its authority contract
- **WHEN** a surface whose current tier is release-allowed holds authority or execution behavior that tier forbids
- **THEN** the execution-trust check fails

### Requirement: Fork pull requests run the baseline without authority
The Ecosystem Baseline SHALL run on the ordinary `pull_request` event, including forks. The caller and every called job SHALL be capped at `contents: read`, with no forwarded secrets, OIDC, cache, self-hosted runner, persisted checkout credential, or override of the pull-request checkout ref.

#### Scenario: Fork caller gains authority
- **WHEN** the fork-PR fixture is mutated to add a write token, secret forwarding, OIDC, cache, self-hosted runner, consumer-code command, or persisted checkout credential
- **THEN** the fork-PR contract test rejects the mutation

#### Scenario: Untrusted probes stay inert
- **WHEN** the baseline evaluates a fork containing lifecycle, token, secret, OIDC, self-hosted-runner, and workflow payload probes
- **THEN** no probe executes and the probes are inspected only as data

#### Scenario: Fork fixture covers every baseline evaluation
- **WHEN** a workflow is declared in the baseline no-execution policy
- **THEN** the fork-PR fixture calls it through a reviewed full commit reference

### Requirement: Privileged triggers are forbidden on consumer evaluation paths
Consumer evaluation workflows SHALL NOT use `pull_request_target`. A workflow triggered by a privileged event SHALL NOT check out or execute an untrusted pull-request head.

#### Scenario: pull_request_target introduced
- **WHEN** a consumer evaluation path uses `pull_request_target`
- **THEN** the fork-PR check fails
