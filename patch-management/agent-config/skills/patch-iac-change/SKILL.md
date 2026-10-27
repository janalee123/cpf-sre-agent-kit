---
name: patch-iac-change
description: Use when a patch or AKS upgrade should be made through infrastructure as code instead of a direct install. Drafts the exact Terraform change (an Update Manager patch window, a one-off emergency window, a KB exclusion, or an AKS version bump) plus the pull request description, for a person to raise, review and merge. Never edits the repository, runs Terraform or installs anything.
tools:
  - RunAzCliReadCommands
---

# Patch change as code

The infrastructure repository is `{{PATCH_IAC_REPO}}`. The patch plan is `patch-as-code/patch-plan.auto.tfvars`.
Update Manager installs updates in the windows that file defines. AKS versions live in the cluster's own
Terraform.

## Guardrails

- Read only. Draft the change; never commit, push, open a pull request, run Terraform, or start an install.
- Change the smallest thing that solves the finding. Do not reformat or reorder unrelated entries.
- Use only evidence collected in this thread or re-read live. Cite the source and UTC timestamp of every fact.
- Follow the {{POLICY_TITLE}} knowledge file for SLAs, windows and approvers. If the policy and the request
  conflict, say so and stop.
- Never propose a window shorter than 01:30 or longer than 03:55, or an emergency window without a change
  reference placeholder.
- An AKS control-plane upgrade cannot be rolled back. Only propose one minor version at a time.

## Choose the change

| Finding | Change to draft |
|---|---|
| Machines need routine updates | None, if their `patch-group` tag already maps to a window that covers them before the SLA due date. Otherwise add the tag, or a new entry under `patch_groups` |
| Known-exploited (KEV) or critical CVE due before the next window | A new entry under `emergency_windows`: the patch group, start time inside the policy SLA, the KB numbers that fix it, `change_ref = "<change-record>"`, and the reason |
| A KB breaks an application | Add it to `kb_exclude` for the affected group, with a review date in the pull request |
| AKS cluster behind on version or node image | In the cluster Terraform: `kubernetes_version` and node pool `orchestrator_version` (next minor only), or `node_os_upgrade_channel` |

## Procedure

1. Confirm the finding from patch-triage, cve-risk-prioritization or aks-upgrade-readiness, or re-run its
   checks. List the target machines or cluster with resource IDs.
2. Read each machine's `patch-group` tag and patch orchestration mode. Machines must use
   `AutomaticByPlatform` with customer-managed schedules; list any that do not as blockers.
3. Read the current maintenance configurations (`az maintenance configuration list`) and assignments, so
   the draft matches what is deployed.
4. Pick the change from the table above and work out the values: dates in `YYYY-MM-DD hh:mm`, the policy
   time zone, KB numbers without the `KB` prefix.
5. For AKS, check `az aks get-upgrades` and confirm the target version is available and supported.

## Output

1. **Summary**: the finding, the change and why it is the smallest fix.
2. **Diff**: a unified diff against the file path, in a `diff` code block.
3. **Pull request description**: title, the evidence table (item, value, source, UTC timestamp), the policy
   SLA and due date, the expected `terraform plan` result (for example `1 to add, 0 to change, 0 to destroy`),
   blockers, rollback, and how to validate after the window.
4. **Approvals needed**: pull request reviewer and pipeline environment approver, using the roles named in
   the policy.
5. The statement: `This is a draft. No repository, Terraform state or machine was changed.`
