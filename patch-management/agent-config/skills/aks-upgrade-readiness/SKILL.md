---
name: aks-upgrade-readiness
description: Use for read-only AKS cluster and node-image upgrade readiness. Compares the live upgrade profile, node images, auto-upgrade and maintenance settings, Advisor and Defender findings, and workload blockers against the CPF patch policy. Never upgrades a cluster.
tools:
  - RunAzCliReadCommands
---

# AKS Upgrade Readiness

## Guardrails

- Read only. Never run `az aks upgrade`, `az aks nodepool upgrade`, `az aks update`, `az aks maintenanceconfiguration add|update|delete`, `az aks command invoke`, start, stop, scale, drain, or cordon.
- Use only the approved AKS clusters in the requested scope.
- Never recommend a target Kubernetes version from model memory. Use only versions returned by `az aks get-upgrades` and `az aks nodepool get-upgrades`.
- If a check cannot be performed with the available read tools, mark it `Unknown` and name the missing source. Never treat a missing check as passed.

## Procedure

1. Record the scope and the UTC retrieval time. For each cluster, read its power state, provisioning state, Kubernetes version, upgrade channel, node OS upgrade channel, support plan, and maintenance configurations (`az aks maintenanceconfiguration list`).
2. Read the available control-plane upgrades (`az aks get-upgrades`). For each node pool, read its version, node image version and available node-image upgrades (`az aks nodepool get-upgrades`).
3. Read the Advisor recommendations for the cluster, and the Defender for Cloud assessments from Resource Graph `securityresources`. Keep the source and timestamp for each finding.
4. Check for upgrade blockers:
   - The cluster is stopped, or its provisioning state is not `Succeeded`.
   - The Kubernetes version is outside support, or in its final supported minor version, according to the live `get-upgrades` result.
   - No maintenance window is configured, or the window conflicts with the CPF policy.
   - Auto-upgrade is `none` while the policy expects an automated channel.
   - Node pools have a single node, or `maxSurge` is unset, so workloads lose capacity during an upgrade.
   - Deprecated Kubernetes APIs are in use, or pod disruption budgets would block a drain. Check these only when a read-only Kubernetes source is connected; otherwise mark them `Unknown – requires in-cluster read access`.
5. Compare the evidence with the CPF patch policy in agent memory. Cite the policy rule for every non-compliant result.

## Output

- A scope line with the UTC retrieval time and the sources queried, each with a status: data returned, empty, denied, or blocked.
- A readiness verdict for each cluster and node pool: `Ready`, `Ready with conditions`, `Blocked` or `Unknown`.
- A table with one row per check: the check, the observed value, the evidence and its timestamp, the policy rule, and the result.
- The available upgrade path, exactly as returned by AKS.
- A recommended execution owner: AKS auto-upgrade, planned maintenance, or a pipeline-driven upgrade. Mark it for human approval.
- An explicit statement: `No cluster, node pool, or maintenance configuration was changed.`

