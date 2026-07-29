# Rollout Operator Guide

**For:** people coordinating security-evaluation adoption across multiple
Filecoin projects.

**Outcome:** a controlled pilot with known owners, policy, coverage, and
rollback.

## Current Status

`ff-sec-actions` is pre-v1. It is suitable for sandbox evaluation and selected
pilots, not mandatory ecosystem-wide enforcement. The G0 trust foundation is
enforced; the evaluation-platform, profile, governance, and release gates must
still complete before a broad rollout.

## Pilot Checklist

For each Consumer Project, record:

- project owner and security contact;
- project class and proposed Security Profile;
- repository visibility and fork contribution model;
- enabled evaluations and known coverage gaps;
- secrets and GitHub product dependencies;
- whether any job builds or executes project code;
- advisory or blocking policy;
- installed `ff-sec-actions` ref;
- exception owner and expiry;
- rollback contact and procedure.

## Rollout Stages

1. **Sandbox:** prove installation and completion behavior.
2. **Observe:** run advisory and measure reliability/noise.
3. **Critical gate:** block only deterministic critical findings and
   unexpected incomplete/error states.
4. **Profile policy:** adopt the tested defaults for that project class.
5. **Managed fleet:** automate upgrades only after rollback and health
   visibility exist.

## Do Not Centralize Blindly

Consumer Project code, findings, and secrets may have different ownership and
confidentiality requirements. Do not aggregate them outside the project until
the distribution, evidence, privacy, and governance decisions explicitly
authorize it.

## Planning References

- [Decision map](../ECOSYSTEM-SECURITY-DECISION-MAP.md)
- [Documentation architecture](../DOCUMENTATION-ARCHITECTURE.md)
- [Consumer quickstart](../consumers/quickstart.md)
- [Understand results](../consumers/understand-results.md)
