# Azure SRE Agent configuration kits (CPF)

Two kits from the CPF proof of concept (POC). Each has its own README, step-by-step guide with
screenshots, agent configuration as code and deploy script.

| Kit | What the agent does | Start here |
|---|---|---|
| [Patch management](patch-management/README.md) | Read-only, cited patch posture across VMs, Arc servers and AKS; CVE risk ranking; exception explanations; change-approval packs; weekly report; patch changes drafted as Terraform for pull request and pipeline approval | [patch-management/docs/step-by-step-guide.md](patch-management/docs/step-by-step-guide.md) |
| [Automated incident response](automated-incident-response/README.md) | Responds to an Azure Monitor alert, investigates read-only, and proposes a fix that goes through GitHub review and human approval (AKS OOM example) | [automated-incident-response/docs/step-by-step-guide.md](automated-incident-response/docs/step-by-step-guide.md) |

## How they relate

- Both kits configure the same kind of resource, an Azure SRE Agent. The Terraform that creates the agent
  and its role assignments is in `patch-management/infra`.
- You can deploy either kit on its own, or both on the same agent. Each deploy script loads only the files
  in its own `agent-config/` folder.
- Both keep the agent in **Review** mode: it investigates and proposes; people approve every change.

```text
patch-management/              Terraform (infra/, patch-as-code/), patch skills, custom agents, policy, prompts, scheduled task
automated-incident-response/   Response plan, investigator custom agent, skill, runbook
```
