# Execution Trust Threats

## 1. Repository Content And Execution

**Boundary attacked:** TB3

### T1: Package Lifecycle Hook Executes In An Inspection Job

**STRIDE:** T, E, I

An attacker adds a lifecycle script to a Node package and the dependency,
license, or SBOM workflow runs `npm ci` or `pnpm install` while inspecting it.

**Attack path:**
1. Add `"preinstall": "node exploit.js"` to `package.json` in a PR.
2. Select or inherit `package-manager: npm` in a scanner job.
3. `npm ci` runs the hook, which reads runner state and sends it over HTTPS.

**Likelihood:** LOW — G0-03 removes package-manager execution and constrains
the three manifest-inspection workflows to reviewed scanner actions.

**Impact:** HIGH — runner compromise and possible credential/evidence theft.

**Note:** Mitigated by G0-03 and its malicious lifecycle-hook fixture.

### T2: Autobuild Or Compiler Executes Hostile Project Behavior

**STRIDE:** T, E, D

CodeQL autobuild, Slither, Foundry, or a compiler invokes project-controlled
build configuration inside a job that also has publication authority.

**Attack path:**
1. Modify a build file, compiler plugin, or generated command in a PR.
2. Enable CodeQL or Slither on the pull request.
3. The build runs before analysis and abuses the job token or corrupts evidence.

**Likelihood:** MEDIUM — the scanners are opt-in but directly build project code.

**Impact:** HIGH — repository write-channel abuse or false security evidence.

**Note:** Fixable by the privileged-build tier; tracked by G0-03/G0-11.

### T3: Persisted Checkout Credential Is Reused By Hostile Code

**STRIDE:** S, E, I

Checkout stores the job token in git configuration. Later project-controlled
execution discovers that credential and invokes GitHub APIs allowed by the job.

**Attack path:**
1. A workflow checks out with the default `persist-credentials: true`.
2. A package hook or build step reads `.git/config` or invokes authenticated git.
3. The attacker uses available token permissions before the job ends.

**Likelihood:** LOW — G0-02 now enforces non-persisted checkout credentials;
the contract prevents regression.

**Impact:** HIGH — blast radius equals the job's effective token permissions.

**Note:** Mitigated by G0-02 and its negative workflow-policy fixtures.

### T4: Broad Or Inherited Authority Reaches The Wrong Evaluation

**STRIDE:** E, T

A consumer grants a broad reusable-workflow permission cap and an inner job
omits explicit permissions or combines inspection/build with writes or OIDC.

**Attack path:**
1. Copy the umbrella example with PR and Security-tab write permissions.
2. Call a nested workflow without a restrictive job permission declaration.
3. Compromised tool code uses authority unrelated to its evaluation purpose.

**Likelihood:** LOW for implicit/broad inheritance — G0-02 now checks every
job against an exact authority policy. Mixed execution and publication remains
separately tracked by T2.

**Impact:** HIGH — comment/SARIF manipulation or broader repository impact if consumer settings expand the cap.

**Note:** Mitigated by G0-02 for missing or excessive job authority.

### T8: Secret-Bearing Scanner Is Exploited By Malicious Input

**STRIDE:** I, E

A parser vulnerability or unsafe behavior in a scanner receives attacker files
in the same job as a provider/license secret.

**Attack path:**
1. Craft repository history or scanner configuration that exploits the scanner.
2. Trigger the Gitleaks or another secret-bearing job.
3. Read the injected secret and exfiltrate it over the runner's network.

**Likelihood:** MEDIUM — requires a tool flaw, but current secret scanning combines both assets.

**Impact:** HIGH — organization credential exposure across consuming projects.

**Note:** Fixable; tracked by G0-06 and privileged-analysis isolation.

### T14: Recursive Submodule Introduces Unreviewed Build Content

**STRIDE:** T, E

An attacker changes a submodule URL/ref; recursive checkout retrieves content
outside the reviewed repository and Slither/Foundry consumes it.

**Attack path:**
1. Modify `.gitmodules` or a gitlink in the PR.
2. Slither checkout follows `submodules: recursive`.
3. The build compiles or otherwise consumes attacker-controlled external content.

**Likelihood:** MEDIUM — Slither currently uses recursive submodules.

**Impact:** HIGH — hidden supply-chain content crosses into project execution.

**Note:** Fixable; tracked by G0-10 and release/profile work.

## 2. Workflow And Tool Supply Chain

**Boundary attacked:** TB4

### T5: Mutable Workflow Or Action Reference Changes After Review

**STRIDE:** T, E

A consumer pins the umbrella but a nested `@main`, `@v1`, or other moving ref
loads different code than the version they reviewed.

**Attack path:**
1. Consumer approves a workflow version.
2. A maintainer or compromised account moves a nested branch/tag.
3. Future runs execute changed code with Consumer Project authority.

**Likelihood:** HIGH — mutable self-references exist in current consumer paths.

**Impact:** CRITICAL — one change can affect many ecosystem repositories.

**Note:** Fixable; tracked by G0-09.

### T6: Mutable Scanner Container Is Replaced

**STRIDE:** T, E

A tagged container resolves to new or compromised bytes while the workflow YAML
still appears unchanged.

**Attack path:**
1. Consumer reviews `semgrep/semgrep:1.93.0`.
2. Registry content for that tag changes or its publisher is compromised.
3. The runner pulls and executes the changed container against project source.

**Likelihood:** MEDIUM — tags are mutable but compromise/replacement is required.

**Impact:** HIGH — source exposure and manipulation of evaluation evidence.

**Note:** Fixable by digest pinning; tracked by G0-09.

## 3. Forks, Events, Caches, And Runners

**Boundary attacked:** TB1 and TB7

### T7: Privileged Event Executes Fork Content

**STRIDE:** E, T

A future attempt to restore fork comments or secrets uses `pull_request_target`
or a privileged `workflow_run` and then checks out or executes the fork head.

**Attack path:**
1. Submit a fork PR containing a malicious script.
2. Trigger a base-repository privileged workflow.
3. The workflow checks out the PR head and runs the script with secrets/write authority.

**Likelihood:** MEDIUM — absent today but a common tempting workaround.

**Impact:** CRITICAL — base repository and secrets can be compromised.

**Note:** Follow-on fork contract; tracked by G0-10 and PRIV-01.

### T9: Untrusted Cache Or Artifact Poisons A Trusted Job

**STRIDE:** T, E

A low-trust job writes reusable state that a later privileged publisher/build
trusts as executable code or authoritative evidence.

**Attack path:**
1. Fork job creates a poisoned cache entry or crafted result artifact.
2. A push, schedule, or `workflow_run` restores/downloads it.
3. The trusted job executes cached content or publishes forged evidence.

**Likelihood:** MEDIUM — current third-party actions use caching/artifacts, but the target flow is not defined.

**Impact:** HIGH — privilege crossing and durable false evidence.

**Note:** Fixable; tracked by G0-10 and EVAL-03.

### T13: Missing Fork Authority Is Reported As Clean

**STRIDE:** R, T

A secret-dependent or publisher job is skipped or degrades on a fork, but the
overall check remains green and communicates zero findings.

**Attack path:**
1. Submit a fork PR where repository secrets are unavailable.
2. Secret-dependent evaluation skips, refuses, or returns empty output.
3. Branch protection sees success and merges without the declared coverage.

**Likelihood:** HIGH — Completion Status and aggregation do not yet exist.

**Impact:** HIGH — systematic false assurance on external contributions.

**Note:** Fixable; tracked by G0-05 and G0-10.

### T15: Self-Hosted Runner Persists Compromise Across Jobs

**STRIDE:** E, I, T

A consumer changes a profile to use a self-hosted runner for untrusted PR code,
allowing persistence beyond the job and access to local networks or later jobs.

**Attack path:**
1. Run a fork PR evaluation on a non-ephemeral self-hosted runner.
2. Malicious build installs persistence or captures runner credentials.
3. Later trusted jobs execute on the compromised host.

**Likelihood:** MEDIUM — no current workflow uses self-hosted, but consumers may adapt examples.

**Impact:** CRITICAL — persistent organization and infrastructure compromise.

**Note:** Unsupported by all defined tiers; enforce through contract/policy.

## 4. External Services And Evidence

**Boundary attacked:** TB5 and TB6

### T10: Tool Failure Or Malformed Output Becomes A Clean Result

**STRIDE:** T, R

`continue-on-error`, missing SARIF, refusal, timeout, or invalid model output is
interpreted as zero findings rather than incomplete/error.

**Attack path:**
1. Trigger a scanner error, provider outage, or maximum-token response.
2. Advisory execution keeps the job green or writes zero findings.
3. Humans or policy accept the run as completed security evaluation.

**Likelihood:** HIGH — multiple present workflows have this behavior.

**Impact:** HIGH — broad false assurance and bypass of intended Merge Gates.

**Note:** Fixable; tracked by G0-04/G0-05 and EVAL-01.

### T11: Source Or Credentials Leave Through Undeclared Egress

**STRIDE:** I

A compromised tool or broad network integration sends private repository source,
metadata, tokens, or findings to an undeclared endpoint.

**Attack path:**
1. Run a scanner against a private Consumer Project.
2. Tool code reads checked-out source or runner credentials.
3. Unrestricted HTTPS sends the data to attacker infrastructure.

**Likelihood:** MEDIUM — requires compromised code; GitHub-hosted egress is broad.

**Impact:** HIGH — private source or credential disclosure.

**Note:** Private-source baseline support requires a separate approved egress design.

### T12: Prompt Injection Manipulates External AI Evidence

**STRIDE:** T, R

PR metadata or source contains instructions that redirect the model, suppress
findings, or manufacture authoritative-looking output.

**Attack path:**
1. Add adversarial instructions to a PR description, comment-like source, or diff.
2. AI review sends that untrusted content in its request.
3. The provider follows the injected instruction and returns misleading findings.

**Likelihood:** HIGH — attacker text is intentionally sent to the model.

**Impact:** MEDIUM — advisory today; higher if used as a sole gate.

**Note:** Fixable only partially; tracked by PRIV-02/PRIV-03.

## Priority Summary

| Priority | Threats | Attack surface |
|---|---|---|
| CRITICAL | T5, T7, T15 | Supply chain, privileged fork events, persistent runners |
| HIGH | T1, T2, T3, T4, T6, T8, T9, T10, T11, T13, T14 | Execution, authority, evidence, egress |
| MEDIUM | T12 | AI evidence integrity |

## Coverage Check

TB1: T7/T13; TB2: T3/T4/T8; TB3: T1/T2/T14; TB4: T5/T6;
TB5: T11/T12; TB6: T9/T10/T13; TB7: T7/T9/T13/T15.
