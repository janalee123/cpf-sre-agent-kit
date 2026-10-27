---
synthetic: true
title: CPF patch policy (demo)
---

# CPF patch policy (synthetic demo values)

> **Demo data.** These values are illustrative placeholders, not CPF's approved policy. Replace them with CPF's actual policy and exception register before the POC.

## Scope

- Azure VMs, Azure Arc-enabled servers (on-premises), and AKS clusters in approved subscriptions.
- The demo environment's subscription is `{{SUBSCRIPTION_ID}}`. Its resource groups are `{{VM_RESOURCE_GROUP}}` (VMs) and `{{AKS_RESOURCE_GROUP}}` (AKS).

## Severity service levels (days from the vendor release date)

| Classification | Production | Non-production |
|---|---|---|
| Critical / Security with known exploitation | 7 | 14 |
| Critical / Security | 14 | 30 |
| Other / feature updates | Next quarterly window | Next monthly window |

## Evidence freshness

- A VM or Arc patch assessment must be 24 hours old or newer for an approval decision, and 7 days old or newer for reporting. Anything older is `Stale`, never `Compliant`.
- Defender findings older than 7 days must be shown with their date.

## Maintenance windows (SGT)

- Production: Saturday 22:00–02:00.
- Non-production: Wednesday 20:00–23:00.
- Every patched resource must have an assigned maintenance configuration or a documented auto-upgrade channel.

## AKS rules

- Run a supported Kubernetes minor version. Plan an upgrade at least 30 days before the version leaves support.
- The node OS upgrade channel must be `NodeImage` or `SecurityPatch`, and node images must be 30 days old or newer.
- Production clusters need a planned maintenance window, at least two nodes per pool, and pod disruption budgets on critical workloads.
- Control-plane minor-version upgrades always need change-board approval.

## Approvals

- Production: the change-board approver and the platform owner.
- Non-production: the platform owner.
- Reboots, AKS minor upgrades, and anything outside a window always need explicit human approval.

## Exception register (demo)

| Resource | Exception | Expires | Owner |
|---|---|---|---|
| `{{EXCEPTION_VM_NAME}}` | Kept deallocated; excluded from SLA while it's off | 2026-12-31 | Platform team |
