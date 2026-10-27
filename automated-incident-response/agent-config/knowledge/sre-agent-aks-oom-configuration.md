# SRE Agent Configuration for AKS OOM and Capacity

## Purpose

Configure Azure SRE Agent to investigate AKS OOMKilled, exit code 137, CrashLoopBackOff, pod memory saturation, and node memory pressure. The investigation must distinguish a workload regression from node pressure and prepare a bounded, human-approved remediation proposal.

## Recommended architecture

- Use a global AKS OOM skill when the procedure is shared across clusters.
- Use a dedicated sub-agent when one platform team owns the workflow or when Kubernetes tools must be tightly scoped.
- Connect Azure Monitor incidents, Container Insights or Log Analytics, Managed Prometheus when available, the application and infrastructure repositories, and the managed AKS resources.
- Add this document and the operational AKS runbook as indexed knowledge sources.
- Keep investigation read-only. Execute rollback, resource changes, or node-pool changes through a separate approved workflow and identity.

## Identity and permissions

- Assign Reader at the AKS resource or containing resource group.
- Assign Log Analytics Reader only to the cluster workspace.
- Assign Azure Kubernetes Service RBAC Reader at the target cluster.
- Do not grant cluster-admin, secrets access, Kubernetes write roles, or resource-group Contributor solely for investigation.
- Scope any remediation identity to the target cluster, namespace, and workload where supported.
- Never use a production write identity for synthetic evidence.

## Tools and sources

- Permit read-only Azure resource, Resource Health, metric, Activity Log, and Log Analytics tools.
- Permit read-only Kubernetes discovery for pods, deployments, replica sets, events, resource requests and limits, previous logs, and node conditions.
- Do not permit generic shell or unrestricted Kubernetes mutation tools on the investigation agent.
- Connect repositories containing manifests, Helm charts, deployment history, image revisions, and Terraform or Bicep.
- Never retrieve Secret values, tokens, kubeconfig credentials, or customer payloads.

## Triggers

- Trigger on OOMKilled termination reason, exit code 137, abnormal restart growth, sustained memory limit saturation, node MemoryPressure, or eviction signals.
- Include cluster, namespace, workload, pod or controller, incident window, and revision in the alert context.
- Deduplicate pod-level alerts to the owning workload and revision.
- Route the incident in read-only mode to the default SRE Agent or dedicated AKS sub-agent.

## Required investigation

1. Confirm cluster, namespace, workload, incident window, revision, and whether evidence is synthetic.
2. Check Azure Resource Health, cluster provisioning state, node readiness, node MemoryPressure, autoscaler state, and recent platform events.
3. Inspect pod status, last termination reason, exit code, restart count, warning events, previous logs, requests, limits, and observed peak memory.
4. Correlate the first failure with deployment and image history.
5. Compare the current revision with the last known-good revision under comparable load.
6. Distinguish workload OOM, node pressure, scheduling shortage, probe or startup failure, and dependency failure.
7. Explain why restarting the same revision would or would not remove the cause.
8. State confidence, conflicting evidence, missing telemetry, and customer impact.

## Remediation approval packet

The agent may propose but must not execute a change. Include:

- Target cluster, namespace, controller, and current revision.
- Exact proposed rollback, resource-limit, replica, VPA, autoscaler, or node-pool change.
- Evidence linking the action to the failure mode.
- Healthy previous revision or capacity prerequisite.
- Expected customer impact, blast radius, maintenance window, and named approver.
- Post-checks, timeout, abort conditions, and roll-forward path.
- IaC or manifest update needed to prevent drift.

## Post-change validation

- Confirm rollout status, desired and ready replicas, restart count, and termination reasons.
- Confirm memory working set, request and limit headroom, node pressure, pending pods, and evictions.
- Confirm error rate, latency, availability, and relevant business transactions.
- Observe for at least one representative load interval before resolving the incident.

## Production defaults

- Use dedicated system node pools, topology spread constraints, PodDisruptionBudgets, and multiple replicas for production workloads.
- Use Managed Prometheus and Container Insights, with control-plane and audit diagnostics sent to Log Analytics.
- Prefer workload identity and Key Vault CSI over static credentials.
- Use VPA recommendations and autoscaling evidence for planning; do not automatically apply resource changes during an incident.
- Avoid B-series nodes for reliability-sensitive production workloads.