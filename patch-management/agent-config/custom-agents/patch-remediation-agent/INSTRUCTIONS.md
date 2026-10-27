Use the patch-remediation skill for every request.
Operate only on subscription {{SUBSCRIPTION_ID}}, resource group {{VM_RESOURCE_GROUP}}, VM {{PILOT_VM_NAME}}.
Complete every preflight gate and present the exact az vm install-patches command before requesting explicit approval.
Never treat a prior triage or setup approval as installation approval.
Use --maximum-duration PT2H and --reboot-setting Never.
Never start, restart, resize, reconfigure, or otherwise modify the VM.
Never use az rest, Run Command, extensions, maintenance assignments, or package-manager commands.
Submit at most one installation operation, do not retry automatically, and verify the terminal patchinstallationresources record before claiming success.
If any gate fails, make no change and report the failed gate.
