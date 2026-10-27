---
name: patch-remediation
description: Use only after patch triage to install approved Critical and Security updates on the named Azure VM. Requires a fresh successful assessment, explicit approval, bounded execution, no automatic reboot, and post-install verification.
tools:
  - RunAzCliReadCommands
  - RunAzCliWriteCommands
---

# Patch Remediation

## Scope

- Subscription: `{{SUBSCRIPTION_ID}}`.
- Resource group: `{{VM_RESOURCE_GROUP}}`.
- Azure VM: `{{PILOT_VM_NAME}}`.
- Reject every other subscription, resource group, resource type, or machine.

## Mandatory Gates

1. Confirm the VM is running and has no Azure resource `ReadOnly` lock.
2. Read current patch settings and query Resource Graph `patchassessmentresources` for this exact VM.
3. Continue only when the latest assessment is `Succeeded`, guest patch support is `Supported`, the assessment is no more than 24 hours old, and at least one Critical or Security update is available.
4. Show the exact target, classifications, maximum duration, reboot setting, assessment timestamp, available update counts, expected impact, and rollback limitation.
5. Require explicit approval for that exact installation command immediately before using the write tool. Approval of triage, setup, or a different command does not count.

## Execution

- Use `az vm install-patches`; do not use `az rest`, shell package managers, Run Command, extensions, maintenance assignments, or patch-setting changes.
- Install only `Critical` and `Security` classifications unless the approval explicitly names a narrower set (Windows: `--classifications-to-include-win Critical Security`; Linux: `--classifications-to-include-linux Critical Security`).
- Set `--maximum-duration PT2H` and `--reboot-setting Never`.
- Never include `Other`, package masks, exclusions, or a reboot without a new, explicit approval that names the added scope.
- Submit one installation operation only. Do not retry a failed or timed-out operation automatically.

## Verification

1. Query Resource Graph `patchinstallationresources` for the submitted operation and report its terminal status, timestamps, installed count, failed count, excluded count, pending count, and errors.
2. Re-read VM power state and reboot-pending state. Do not restart or start the VM.
3. If a reboot is required, stop and return a separate reboot approval packet.
4. Do not claim success until the installation record is terminal and reports zero failed updates.

## Output

Return the approved command, operation ID, evidence timestamps, per-status counts, errors, reboot requirement, and an explicit statement of what changed. If any gate fails, make no change and identify the failed gate.
