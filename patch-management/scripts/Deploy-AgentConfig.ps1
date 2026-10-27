#Requires -Version 7.0
<#
.SYNOPSIS
    Loads the agent configuration (skills, custom agents, knowledge, common prompts, scheduled tasks and response plans)
    from ../agent-config into an Azure SRE Agent.

.DESCRIPTION
    Configuration as code for the SRE Agent data plane. Every item in ../agent-config is a plain file
    in source control; this script substitutes {{TOKENS}} from a parameters file and pushes the result
    to the agent's data-plane API.

      Skills          PUT  /api/v2/extendedAgent/skills/{name}          (idempotent)
      Custom agents   PUT  /api/v2/extendedAgent/agents/{name}          (idempotent)
      Common prompts  PUT  /api/v2/extendedAgent/commonprompts/{name}   (idempotent)
      Knowledge       POST /api/v1/AgentMemory/upload                    (multipart, replaces same file name)
      Scheduled tasks POST /api/v1/scheduledtasks                        (created once; use -ReplaceScheduledTasks to recreate)
      Response plans  PUT  /api/v2/incidentManagement/incidentFilters/{id}   (create; PATCH when it already exists)

    Custom agents that list mcpTools need the matching MCP connector (for example Microsoft Teams) on the
    agent first. Use -SkipMcpTools to deploy them without those tools.

    Write-access skills and custom agents (readOnly = false) are skipped unless -IncludeWriteSkills is set.

.EXAMPLE
    ./Deploy-AgentConfig.ps1 -SubscriptionId <sub> -ResourceGroup rg-sre-agent-patch -AgentName sre-agent-patch -WhatIf

.EXAMPLE
    ./Deploy-AgentConfig.ps1 -SubscriptionId <sub> -ResourceGroup rg-sre-agent-patch -AgentName sre-agent-patch

.EXAMPLE
    ./Deploy-AgentConfig.ps1 -SubscriptionId <sub> -ResourceGroup rg-sre-agent-patch -AgentName sre-agent-patch -VerifyOnly

.EXAMPLE
    # Recreate only the scheduled task (for example, to reset its mode to review)
    ./Deploy-AgentConfig.ps1 -SubscriptionId <sub> -ResourceGroup rg-sre-agent-patch -AgentName sre-agent-patch -Only ScheduledTasks -ReplaceScheduledTasks
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $AgentName,
    [string] $ParametersFile = (Join-Path $PSScriptRoot '..' 'agent-config' 'parameters.json'),
    [string] $ConfigRoot = (Join-Path $PSScriptRoot '..' 'agent-config'),
    [switch] $IncludeWriteSkills,
    [switch] $ReplaceScheduledTasks,
    [switch] $VerifyOnly,
    [switch] $SkipMcpTools,
    [ValidateSet('Skills', 'CustomAgents', 'Knowledge', 'Prompts', 'ScheduledTasks', 'ResponsePlans')] [string[]] $Only
)

$ErrorActionPreference = 'Stop'

function Write-Step([string] $Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string] $Message) { Write-Host "    [ok]   $Message" -ForegroundColor Green }
function Write-Skip([string] $Message) { Write-Host "    [skip] $Message" -ForegroundColor Yellow }
function Write-Miss([string] $Message) { Write-Host "    [miss] $Message" -ForegroundColor Red }

function Expand-Tokens([string] $Text, [hashtable] $Values) {
    foreach ($key in $Values.Keys) { $Text = $Text.Replace("{{$key}}", [string] $Values[$key]) }
    $left = [regex]::Matches($Text, '\{\{([A-Z_]+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    if ($left) { throw "Unresolved tokens: $($left -join ', '). Add them to $ParametersFile." }
    return $Text
}

function Invoke-AgentApi([string] $Method, [string] $Path, $Body, [string] $ContentType = 'application/json') {
    $uri = "$script:Endpoint$Path"
    $req = @{ Method = $Method; Uri = $uri; Headers = $script:Headers }
    if ($null -ne $Body) {
        if ($Body -is [hashtable] -and $ContentType -eq 'multipart') { $req.Form = $Body }
        else { $req.Body = ($Body | ConvertTo-Json -Depth 10); $req.ContentType = $ContentType }
    }
    $result = Invoke-RestMethod @req
    # Invoke-RestMethod returns JSON arrays as one object; unwrap so callers can filter items.
    if ($result -is [array]) { $result | ForEach-Object { $_ } } else { $result }
}

# --- Parameters -----------------------------------------------------------------------------------
if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile. Copy agent-config/parameters.example.json to parameters.json and fill it in."
}
$values = @{}
(Get-Content $ParametersFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $values[$_.Name] = $_.Value }
if (-not $values.ContainsKey('AGENT_NAME') -or $values.AGENT_NAME -like '<*') { $values.AGENT_NAME = $AgentName }
if (-not $values.ContainsKey('SUBSCRIPTION_ID') -or $values.SUBSCRIPTION_ID -like '<*') { $values.SUBSCRIPTION_ID = $SubscriptionId }
$promptPrefix = if ($values.ContainsKey('PROMPT_PREFIX')) { [string] $values.PROMPT_PREFIX } else { '' }

# --- Resolve the agent endpoint and token ---------------------------------------------------------
Write-Step "Resolving agent $AgentName"
$agentJson = az resource show --subscription $SubscriptionId -g $ResourceGroup -n $AgentName `
    --resource-type Microsoft.App/agents -o json 2>$null
if (-not $agentJson) { throw "Agent $AgentName not found in $ResourceGroup. Run terraform apply first and check 'az login'." }
$agent = $agentJson | ConvertFrom-Json
$script:Endpoint = $agent.properties.agentEndpoint.TrimEnd('/')
$token = az account get-access-token --resource https://azuresre.dev --query accessToken -o tsv
if (-not $token) { throw "Could not get a data-plane token. Run 'az login' with an account that has a role on the agent." }
$script:Headers = @{ Authorization = "Bearer $token" }
Write-Ok "Endpoint resolved"

# --- Load desired state from files ----------------------------------------------------------------
# Folders that do not exist are treated as empty, so a kit can include only the item types it needs.
function Get-ConfigItems([string] $Folder, [string] $Filter = '*', [switch] $Directory) {
    $path = Join-Path $ConfigRoot $Folder
    if (-not (Test-Path $path)) { return @() }
    Get-ChildItem $path -Filter $Filter -Directory:$Directory
}
$skills = Get-ConfigItems 'skills' -Directory | ForEach-Object {
    $meta = Get-Content (Join-Path $_.FullName 'skill.json') -Raw | ConvertFrom-Json
    [pscustomobject]@{
        Name        = $_.Name
        Description = $meta.description
        ReadOnly    = [bool] $meta.readOnly
        Content     = Expand-Tokens (Get-Content (Join-Path $_.FullName 'SKILL.md') -Raw) $values
    }
}
$customAgents = @()
$customAgentRoot = Join-Path $ConfigRoot 'custom-agents'
if (Test-Path $customAgentRoot) {
    $customAgents = Get-ChildItem $customAgentRoot -Directory | ForEach-Object {
        $meta = Get-Content (Join-Path $_.FullName 'agent.json') -Raw | ConvertFrom-Json
        [pscustomobject]@{
            Name          = $_.Name
            Description   = $meta.description
            ReadOnly      = [bool] $meta.readOnly
            Tools         = @($meta.tools)
            McpTools      = @($meta.mcpTools | Where-Object { $_ })
            AllowedSkills = @($meta.allowedSkills)
            Handoffs      = @($meta.handoffs)
            Instructions  = Expand-Tokens (Get-Content (Join-Path $_.FullName 'INSTRUCTIONS.md') -Raw) $values
        }
    }
}
$prompts = Get-ConfigItems 'prompts' -Filter *.md | ForEach-Object {
    [pscustomobject]@{ Name = "$promptPrefix$($_.BaseName)"; Content = Expand-Tokens (Get-Content $_.FullName -Raw) $values }
}
$knowledge = Get-ConfigItems 'knowledge' -Filter *.md | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Content = Expand-Tokens (Get-Content $_.FullName -Raw) $values }
}
$tasks = Get-ConfigItems 'scheduled-tasks' -Filter *.json | ForEach-Object {
    $t = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $t.agentPrompt = Expand-Tokens $t.agentPrompt $values
    $t
}
$responsePlans = @()
$responsePlanRoot = Join-Path $ConfigRoot 'response-plans'
if (Test-Path $responsePlanRoot) {
    $responsePlans = Get-ChildItem $responsePlanRoot -Filter *.json | ForEach-Object {
        Expand-Tokens (Get-Content $_.FullName -Raw) $values | ConvertFrom-Json
    }
}

# --- Verify-only: compare desired state with the live agent ---------------------------------------
if ($VerifyOnly) {
    Write-Step 'Verifying live configuration (read only)'
    $liveSkills = (Invoke-AgentApi GET '/api/v2/extendedAgent/skills' $null) | ForEach-Object { if ($_.value) { $_.value } else { $_ } } | ForEach-Object name
    $livePrompts = (Invoke-AgentApi GET '/api/v2/extendedAgent/commonprompts' $null).value.name
    $liveTasks = @(Invoke-AgentApi GET '/api/v1/scheduledtasks' $null)
    $liveDocs = (Invoke-AgentApi GET '/api/v1/AgentMemory/files' $null | ConvertTo-Json -Depth 6)
    foreach ($s in $skills) {
        if (-not $s.ReadOnly -and -not $IncludeWriteSkills) { continue }
        if ($liveSkills -contains $s.Name) { Write-Ok "skill $($s.Name)" } else { Write-Miss "skill $($s.Name)" }
    }
    $liveAgents = (Invoke-AgentApi GET '/api/v2/extendedAgent/agents' $null) | ForEach-Object { if ($_.value) { $_.value } else { $_ } } | ForEach-Object name
    foreach ($a in $customAgents) {
        if (-not $a.ReadOnly -and -not $IncludeWriteSkills) { continue }
        if ($liveAgents -contains $a.Name) { Write-Ok "custom agent $($a.Name)" } else { Write-Miss "custom agent $($a.Name)" }
    }
    foreach ($p in $prompts) { if ($livePrompts -contains $p.Name) { Write-Ok "prompt $($p.Name)" } else { Write-Miss "prompt $($p.Name)" } }
    foreach ($k in $knowledge) { if ($liveDocs -match [regex]::Escape($k.Name)) { Write-Ok "knowledge $($k.Name)" } else { Write-Miss "knowledge $($k.Name)" } }
    foreach ($t in $tasks) {
        $live = $liveTasks | Where-Object name -eq $t.name | Select-Object -First 1
        if (-not $live) { Write-Miss "scheduled task $($t.name)" }
        elseif ($live.agentMode -ne $t.agentMode) { Write-Miss "scheduled task $($t.name) mode is '$($live.agentMode)', expected '$($t.agentMode)'" }
        else { Write-Ok "scheduled task $($t.name) ($($live.cronExpression), $($live.agentMode))" }
    }
    foreach ($r in $responsePlans) {
        $live = try { (Invoke-AgentApi GET "/api/v2/incidentManagement/incidentFilters/$([uri]::EscapeDataString($r.id))" $null).properties } catch { $null }
        if (-not $live) { Write-Miss "response plan $($r.id)" }
        elseif ($live.handlingAgent -ne $r.handlingAgent -or $live.agentMode -ne $r.agentMode) { Write-Miss "response plan $($r.id) routes to '$($live.handlingAgent)' in '$($live.agentMode)' mode, expected '$($r.handlingAgent)' in '$($r.agentMode)'" }
        else { Write-Ok "response plan $($r.id) ($($live.handlingAgent), $($live.agentMode), enabled=$($live.isEnabled))" }
    }
    return
}

# --- Apply ----------------------------------------------------------------------------------------
if ($Only) {
    if ($Only -notcontains 'Skills') { $skills = @() }
    if ($Only -notcontains 'CustomAgents') { $customAgents = @() }
    if ($Only -notcontains 'Knowledge') { $knowledge = @() }
    if ($Only -notcontains 'Prompts') { $prompts = @() }
    if ($Only -notcontains 'ScheduledTasks') { $tasks = @() }
    if ($Only -notcontains 'ResponsePlans') { $responsePlans = @() }
}

Write-Step 'Skills'
foreach ($s in $skills) {
    if (-not $s.ReadOnly -and -not $IncludeWriteSkills) { Write-Skip "$($s.Name) (write access; add -IncludeWriteSkills)"; continue }
    $body = @{ name = $s.Name; type = 'Skill'; properties = @{ skillContent = $s.Content; description = $s.Description } }
    if ($PSCmdlet.ShouldProcess($s.Name, 'PUT skill')) {
        Invoke-AgentApi PUT "/api/v2/extendedAgent/skills/$([uri]::EscapeDataString($s.Name))" $body | Out-Null
        Write-Ok $s.Name
    }
}

Write-Step 'Custom agents'
foreach ($a in $customAgents) {
    if (-not $a.ReadOnly -and -not $IncludeWriteSkills) { Write-Skip "$($a.Name) (write access; add -IncludeWriteSkills)"; continue }
    $body = @{
        name       = $a.Name
        type       = 'ExtendedAgent'
        properties = @{
            instructions       = $a.Instructions
            handoffDescription = $a.Description
            handoffs           = $a.Handoffs
            tools              = $a.Tools
            mcpTools           = if ($SkipMcpTools) { @() } else { $a.McpTools }
            enableSkills       = $true
            allowedSkills      = $a.AllowedSkills
        }
    }
    if ($PSCmdlet.ShouldProcess($a.Name, 'PUT custom agent')) {
        Invoke-AgentApi PUT "/api/v2/extendedAgent/agents/$([uri]::EscapeDataString($a.Name))" $body | Out-Null
        Write-Ok $a.Name
    }
}

Write-Step 'Knowledge'
foreach ($k in $knowledge) {
    if ($PSCmdlet.ShouldProcess($k.Name, 'Upload knowledge')) {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) $k.Name
        Set-Content -Path $tmp -Value $k.Content -Encoding utf8 -NoNewline
        try { Invoke-AgentApi POST '/api/v1/AgentMemory/upload' @{ files = Get-Item $tmp } 'multipart' | Out-Null }
        finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
        Write-Ok $k.Name
    }
}

Write-Step 'Common prompts'
foreach ($p in $prompts) {
    $body = @{ name = $p.Name; type = 'CommonPrompt'; properties = @{ prompt = $p.Content } }
    if ($PSCmdlet.ShouldProcess($p.Name, 'PUT common prompt')) {
        Invoke-AgentApi PUT "/api/v2/extendedAgent/commonprompts/$([uri]::EscapeDataString($p.Name))" $body | Out-Null
        Write-Ok $p.Name
    }
}

Write-Step 'Scheduled tasks'
$existing = @()
if (-not $WhatIfPreference) { $existing = @(Invoke-AgentApi GET '/api/v1/scheduledtasks' $null) }
foreach ($t in $tasks) {
    $match = $existing | Where-Object name -eq $t.name
    if ($match -and -not $ReplaceScheduledTasks) { Write-Skip "$($t.name) already exists (add -ReplaceScheduledTasks to recreate)"; continue }
    if ($PSCmdlet.ShouldProcess($t.name, 'Create scheduled task')) {
        foreach ($m in $match) { Invoke-AgentApi DELETE "/api/v1/scheduledtasks/$($m.id)" $null | Out-Null }
        $body = @{
            name           = $t.name
            agent          = $AgentName
            cronExpression = $t.cronExpression
            agentPrompt    = $t.agentPrompt
            description    = $t.description
            agentMode      = $t.agentMode
        }
        $created = Invoke-AgentApi POST '/api/v1/scheduledtasks' $body
        Write-Ok "$($t.name) ($($t.cronExpression))"
        if ($created.agentMode -and $created.agentMode -ne $t.agentMode) {
            Write-Warning "$($t.name) was created in '$($created.agentMode)' mode. Open Scheduled tasks in the portal and set it to '$($t.agentMode)'."
        }
    }
}

Write-Step 'Response plans'
foreach ($r in $responsePlans) {
    $props = [ordered]@{}
    $r.PSObject.Properties | Where-Object Name -ne 'id' | ForEach-Object { $props[$_.Name] = $_.Value }
    $body = @{ name = $r.id; type = 'IncidentFilter'; properties = $props }
    $path = "/api/v2/incidentManagement/incidentFilters/$([uri]::EscapeDataString($r.id))"
    if ($PSCmdlet.ShouldProcess($r.id, 'Create or update response plan')) {
        $exists = try { Invoke-AgentApi GET $path $null } catch { $null }
        if ($exists) { Invoke-AgentApi PATCH $path $body | Out-Null; Write-Ok "$($r.id) updated (-> $($r.handlingAgent), $($r.agentMode))" }
        else { Invoke-AgentApi PUT $path $body | Out-Null; Write-Ok "$($r.id) created (-> $($r.handlingAgent), $($r.agentMode))" }
    }
}

Write-Step 'Done. Run again with -VerifyOnly to confirm the live state.'
