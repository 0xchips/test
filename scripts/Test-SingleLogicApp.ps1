<#
.SYNOPSIS
    Test script to export and document a single Logic App

.DESCRIPTION
    This script exports and generates documentation for a specific Logic App
    to test the system before running on all Logic Apps.

.PARAMETER LogicAppName
    Name of the Logic App to export and document

.PARAMETER ResourceGroupName
    Resource Group containing the Logic App (optional - will search if not provided)

.EXAMPLE
    .\Test-SingleLogicApp.ps1 -LogicAppName "MULTI-EmailReportedResults-Prod-00010"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./exports/test"
)

# Import helper functions
. "$PSScriptRoot/Helpers.ps1"

Write-LogInfo "=========================================="
Write-LogInfo "Testing Logic App Documentation System"
Write-LogInfo "Target: $LogicAppName"
Write-LogInfo "=========================================="
Write-Host ""

# Ensure output directories exist
$exportPath = "$OutputPath/logicapps"
$docsPath = "$OutputPath/docs"

if (-not (Test-Path $exportPath)) {
    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
    Write-LogInfo "Created export directory: $exportPath"
}

if (-not (Test-Path $docsPath)) {
    New-Item -ItemType Directory -Path $docsPath -Force | Out-Null
    Write-LogInfo "Created docs directory: $docsPath"
}

# Check Azure connection
Write-LogInfo "Checking Azure connection..."
$context = Get-AzContext
if (-not $context) {
    Write-LogError "Not connected to Azure. Please run: Connect-AzAccount"
    exit 1
}

Write-LogSuccess "Connected to subscription: $($context.Subscription.Name)"
Write-LogInfo "Subscription ID: $($context.Subscription.Id)"
Write-Host ""

# Find the Logic App if resource group not specified
if (-not $ResourceGroupName) {
    Write-LogInfo "Searching for Logic App: $LogicAppName"
    
    $allLogicApps = Get-AzLogicApp
    $targetApp = $allLogicApps | Where-Object { $_.Name -eq $LogicAppName }
    
    if (-not $targetApp) {
        Write-LogError "Logic App '$LogicAppName' not found in subscription"
        Write-LogWarning "Available Logic Apps:"
        $allLogicApps | Select-Object Name, ResourceGroupName, State | Format-Table
        exit 1
    }
    
    $ResourceGroupName = $targetApp.ResourceGroupName
    Write-LogSuccess "Found Logic App in resource group: $ResourceGroupName"
}
else {
    Write-LogInfo "Using specified resource group: $ResourceGroupName"
}

Write-Host ""

# Step 1: Export the Logic App
Write-LogInfo "=========================================="
Write-LogInfo "STEP 1: Exporting Logic App"
Write-LogInfo "=========================================="
Write-Host ""

try {
    # Get full workflow definition
    Write-LogInfo "Retrieving workflow definition..."
    $workflow = Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName
    
    if (-not $workflow) {
        Write-LogError "Failed to retrieve Logic App"
        exit 1
    }
    
    Write-LogSuccess "Retrieved workflow: $($workflow.Name)"
    Write-LogInfo "  State: $($workflow.State)"
    Write-LogInfo "  Location: $($workflow.Location)"
    Write-LogInfo "  Created: $($workflow.CreatedTime)"
    Write-Host ""
    
    # Get run history (use Select-Object -First to limit results)
    Write-LogInfo "Retrieving run history (last 30 runs)..."
    try {
        $runs = Get-AzLogicAppRunHistory -ResourceGroupName $ResourceGroupName -Name $LogicAppName -ErrorAction Stop | Select-Object -First 30
        $runStats = @{
            TotalRuns = $runs.Count
            Succeeded = ($runs | Where-Object { $_.Status -eq 'Succeeded' }).Count
            Failed = ($runs | Where-Object { $_.Status -eq 'Failed' }).Count
            Cancelled = ($runs | Where-Object { $_.Status -eq 'Cancelled' }).Count
            Running = ($runs | Where-Object { $_.Status -eq 'Running' }).Count
        }
        Write-LogSuccess "Retrieved $($runs.Count) run(s) from history"
    }
    catch {
        Write-LogWarning "Could not retrieve run history: $_"
        $runStats = @{
            TotalRuns = 0
            Succeeded = 0
            Failed = 0
            Cancelled = 0
            Running = 0
        }
    }
    Write-Host ""
    
    # Parse the Definition JSON (it's a JObject, needs conversion)
    Write-LogInfo "Parsing workflow definition..."
    $definitionObj = $workflow.Definition.ToString() | ConvertFrom-Json
    
    # Extract connections from Parameters (not Definition)
    Write-LogInfo "Extracting connections..."
    $connections = @()
    
    # Parameters.$connections.Value is also a JObject, needs conversion
    if ($workflow.Parameters -and $workflow.Parameters.'$connections' -and $workflow.Parameters.'$connections'.Value) {
        try {
            # Convert JObject to PowerShell object
            $connectionParams = $workflow.Parameters.'$connections'.Value.ToString() | ConvertFrom-Json
            
            # Iterate through connection properties
            foreach ($connName in $connectionParams.PSObject.Properties.Name) {
                $conn = $connectionParams.$connName
                $connections += @{
                    ConnectionName = if ($conn.connectionName) { $conn.connectionName } else { $connName }
                    ConnectionId = if ($conn.connectionId) { $conn.connectionId } else { $conn.id }
                    ConnectionProperties = $conn
                }
            }
        }
        catch {
            Write-LogWarning "Failed to parse connections: $_"
        }
    }
    
    Write-LogSuccess "Found $($connections.Count) connection(s)"
    if ($connections.Count -gt 0) {
        foreach ($conn in $connections) {
            Write-LogInfo "  - $($conn.ConnectionName)"
        }
    }
    Write-Host ""
    
    # Extract triggers
    Write-LogInfo "Extracting triggers..."
    $triggers = @()
    if ($definitionObj.triggers) {
        foreach ($triggerName in $definitionObj.triggers.PSObject.Properties.Name) {
            $trigger = $definitionObj.triggers.$triggerName
            $triggers += @{
                Name = $triggerName
                Type = $trigger.type
                Recurrence = $trigger.recurrence
                Conditions = $trigger.inputs
            }
        }
    }
    Write-LogSuccess "Found $($triggers.Count) trigger(s)"
    Write-Host ""
    
    # Extract actions
    Write-LogInfo "Extracting actions..."
    $actions = @()
    if ($definitionObj.actions) {
        foreach ($actionName in $definitionObj.actions.PSObject.Properties.Name) {
            $action = $definitionObj.actions.$actionName
            $actions += @{
                Name = $actionName
                Type = $action.type
                RunAfter = $action.runAfter
                Inputs = $action.inputs
            }
        }
    }
    Write-LogSuccess "Found $($actions.Count) action(s)"
    Write-Host ""
    
    # Build comprehensive export
    $logicAppInfo = @{
        Name = $workflow.Name
        ResourceGroupName = $ResourceGroupName  # Use parameter value instead of workflow property
        Location = $workflow.Location
        State = $workflow.State
        Id = $workflow.Id
        CreatedTime = $workflow.CreatedTime
        ChangedTime = $workflow.ChangedTime
        Version = $workflow.Version
        AccessEndpoint = $workflow.AccessEndpoint
        Definition = $workflow.Definition
        Parameters = $workflow.Parameters
        Triggers = $triggers
        Actions = $actions
        Connections = $connections
        RunHistory = $runStats
        Tags = $workflow.Tags
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Save to JSON
    $exportFile = Join-Path -Path $exportPath -ChildPath "$LogicAppName.json"
    $logicAppInfo | ConvertTo-Json -Depth 20 | Out-File -FilePath $exportFile -Encoding UTF8
    Write-LogSuccess "Exported to: $exportFile"
    
    $fileSize = (Get-Item $exportFile).Length
    Write-LogInfo "  File size: $(Format-FileSize -Bytes $fileSize)"
}
catch {
    Write-LogError "Failed to export Logic App: $_"
    Write-LogError $_.ScriptStackTrace
    exit 1
}

Write-Host ""
Write-Host ""

# Step 2: Generate Documentation
Write-LogInfo "=========================================="
Write-LogInfo "STEP 2: Generating Documentation"
Write-LogInfo "=========================================="
Write-Host ""

try {
    # Read the exported JSON
    $exportedData = Get-Content -Path $exportFile -Raw | ConvertFrom-Json
    
    Write-LogInfo "Generating markdown documentation..."
    
    # Create sanitized filename
    $docFileName = "$(Get-SanitizedFileName -Name $LogicAppName).md"
    $docFilePath = Join-Path -Path $docsPath -ChildPath $docFileName
    
    # Generate Mermaid diagram
    Write-LogInfo "Creating workflow diagram..."
    $diagram = New-MermaidDiagram -Workflow $exportedData
    
    # Build markdown content
    $successRate = Get-RunSuccessRate -RunHistory $exportedData.RunHistory
    $statusColor = Get-StatusBadgeColor -State $exportedData.State
    
    $markdown = @"
# $($exportedData.Name)

> **Status:** ![Status](https://img.shields.io/badge/Status-$($exportedData.State)-$statusColor)  
> **Last Modified:** $($exportedData.ChangedTime)  
> **Location:** $($exportedData.Location)

## Overview

| Property | Value |
|----------|-------|
| **Name** | $($exportedData.Name) |
| **Resource Group** | $($exportedData.ResourceGroupName) |
| **State** | $($exportedData.State) |
| **Location** | $($exportedData.Location) |
| **Created** | $($exportedData.CreatedTime) |
| **Last Changed** | $($exportedData.ChangedTime) |
| **Tags** | $(Format-Tags -Tags $exportedData.Tags) |

## Access Endpoint

``````
$($exportedData.AccessEndpoint)
``````

---

## 📊 Performance Metrics (Last 30 Days)

| Metric | Count |
|--------|-------|
| **Total Runs** | $($exportedData.RunHistory.TotalRuns) |
| **✅ Succeeded** | $($exportedData.RunHistory.Succeeded) |
| **❌ Failed** | $($exportedData.RunHistory.Failed) |
| **⏸️ Cancelled** | $($exportedData.RunHistory.Cancelled) |
| **🔄 Running** | $($exportedData.RunHistory.Running) |
| **Success Rate** | $successRate% |

---

## 🔄 Workflow Diagram

``````mermaid
$diagram
``````

---

## ⚡ Triggers

"@

    if ($exportedData.Triggers -and $exportedData.Triggers.Count -gt 0) {
        foreach ($trigger in $exportedData.Triggers) {
            $triggerType = Get-TriggerTypeDisplayName -Type $trigger.Type
            $markdown += @"

### $($trigger.Name)

- **Type:** $triggerType
- **Recurrence:** $(Format-RecurrenceSchedule -Recurrence $trigger.Recurrence)

"@
            if ($trigger.Conditions) {
                $markdown += @"
**Configuration:**

``````json
$($trigger.Conditions | ConvertTo-Json -Depth 5)
``````

"@
            }
        }
    }
    else {
        $markdown += "`n*No triggers defined*`n"
    }
    
    $markdown += "`n---`n`n## 🎯 Actions`n"
    
    if ($exportedData.Actions -and $exportedData.Actions.Count -gt 0) {
        $actionNumber = 1
        foreach ($action in $exportedData.Actions) {
            $actionType = Get-ActionTypeDisplayName -Type $action.Type
            $markdown += @"

### $actionNumber. $($action.Name)

- **Type:** $actionType

"@
            if ($action.RunAfter -and $action.RunAfter.PSObject.Properties.Count -gt 0) {
                $runAfterActions = ($action.RunAfter.PSObject.Properties.Name) -join ", "
                $markdown += "- **Run After:** $runAfterActions`n"
            }
            
            if ($action.Inputs) {
                $markdown += @"

**Inputs:**

``````json
$($action.Inputs | ConvertTo-Json -Depth 5)
``````

"@
            }
            $markdown += "`n"
            $actionNumber++
        }
    }
    else {
        $markdown += "`n*No actions defined*`n"
    }
    
    $markdown += "`n---`n`n## Logic App Connections`n`n"
    $markdown += "This section shows an overview of Logic App Workflow connections.`n`n"
    $markdown += "### Connections`n`n"
    
    if ($exportedData.Connections -and $exportedData.Connections.Count -gt 0) {
        # Create table header
        $markdown += "| ConnectionName | ConnectionId | ConnectionProperties |`n"
        $markdown += "| -------------- | ------------ | -------------------- |`n"
        
        # Add rows
        foreach ($conn in $exportedData.Connections) {
            $connectionName = $conn.ConnectionName
            $connectionId = $conn.ConnectionId
            # Format connection properties (if available)
            $connectionProps = if ($conn.ConnectionProperties) { 
                ($conn.ConnectionProperties | ConvertTo-Json -Compress -Depth 2) -replace '\|', '\|' 
            } else { 
                "null" 
            }
            $markdown += "| $connectionName | $connectionId | $connectionProps |`n"
        }
        $markdown += "`n"
    }
    else {
        $markdown += "`n*No external connections*`n`n"
    }
    
    $markdown += @"

---

## 📝 Metadata

- **Resource ID:** ``$($exportedData.Id)``
- **API Version:** $($exportedData.Version)
- **Documentation Generated:** $(Get-DocumentationTimestamp)

---

*Generated by Logic Apps Documentation Test Script*
"@

    # Save markdown
    $markdown | Out-File -FilePath $docFilePath -Encoding UTF8
    Write-LogSuccess "Documentation saved to: $docFilePath"
    
    $docSize = (Get-Item $docFilePath).Length
    Write-LogInfo "  File size: $(Format-FileSize -Bytes $docSize)"
}
catch {
    Write-LogError "Failed to generate documentation: $_"
    Write-LogError $_.ScriptStackTrace
    exit 1
}

Write-Host ""
Write-Host ""

# Summary
Write-LogInfo "=========================================="
Write-LogSuccess "TEST COMPLETED SUCCESSFULLY!"
Write-LogInfo "=========================================="
Write-Host ""
Write-LogInfo "Summary:"
Write-LogInfo "  Logic App: $LogicAppName"
Write-LogInfo "  Resource Group: $ResourceGroupName"
Write-LogInfo "  State: $($workflow.State)"
Write-LogInfo "  Triggers: $($triggers.Count)"
Write-LogInfo "  Actions: $($actions.Count)"
Write-LogInfo "  Connections: $($connections.Count)"
Write-LogInfo "  Total Runs (30d): $($runStats.TotalRuns)"
Write-Host ""
Write-LogInfo "Files created:"
Write-LogInfo "  Export: $exportFile"
Write-LogInfo "  Documentation: $docFilePath"
Write-Host ""
Write-LogSuccess "✅ You can now view the documentation in your markdown viewer!"
Write-LogInfo "Next steps:"
Write-LogInfo "  1. Review the generated documentation: $docFilePath"
Write-LogInfo "  2. If satisfied, run the full export: ./scripts/Export-LogicApps.ps1"
Write-LogInfo "  3. Generate full documentation: ./scripts/Generate-LogicAppsDoc.ps1"
Write-Host ""
