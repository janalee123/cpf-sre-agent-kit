---
name: patch-approval-pack
description: Use to prepare a change-approval evidence pack for a proposed patch or AKS upgrade, after patch-triage or aks-upgrade-readiness has run. Summarizes scope, evidence, risk, window, rollback and validation for a human approver. Never approves or executes the change.
tools:
  - RunAzCliReadCommands
---

# Patch Approval Pack

## Guardrails

- Read only. This skill prepares evidence for a human approver. It never approves, schedules, or executes a change, and it never creates a change ticket unless a write-enabled connector is approved separately.
- Use only evidence collected in this thread or re-read live. Cite the source and UTC timestamp of every fact.
- If evidence is older than the policy freshness limit, or missing, mark the pack `Not ready` and list the gaps.

## Procedure

1. Confirm the proposed change: the exact targets (resource IDs), the update classifications or the target AKS version as returned live, the execution mechanism (Update Manager, AKS auto-upgrade or planned maintenance), the maintenance window, and the reboot setting.
2. Re-read the current state of each target, and the freshness of its assessment or upgrade profile.
3. Map each target to the CPF patch policy: severity, SLA due date, required window, approver role, and any registered exception.
4. Summarize the risk: business criticality, blast radius, dependencies, reboot or drain impact, capacity headroom, and known blockers from the readiness checks.
5. State the rollback and its limits. OS patches can't always be uninstalled, and an AKS control-plane upgrade can't be downgraded.
6. Define the post-change validation: the Resource Graph checks, health signals, and success criteria.

## Output

A Markdown pack with the following sections:

1. Change summary: what, where, when, how, and who executes.
2. Readiness verdict: `Ready for approval`, `Ready with conditions`, or `Not ready`.
3. An evidence table: item, value, source, and UTC timestamp.
4. Policy mapping and SLA status.
5. Risks and mitigations.
6. Rollback and limitations.
7. Validation plan.
8. An approver checklist, using the role named by the policy.
9. An explicit statement: `This pack does not approve or execute the change.`

