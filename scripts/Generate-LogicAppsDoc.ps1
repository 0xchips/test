<#
.SYNOPSIS
    Generates comprehensive markdown documentation for Logic Apps

.DESCRIPTION
    This script reads exported Logic Apps JSON files and generates detailed 
    markdown documentation including workflow diagrams, trigger/action details,
    connections, and run statistics.

.PARAMETER InputPath
    Path to the directory containing exported Logic Apps JSON files

.PARAMETER OutputPath
    Path where generated documentation markdown files will be saved

.PARAMETER GenerateDiagrams
    Generate Mermaid diagrams for workflows

.EXAMPLE
    .\Generate-LogicAppsDoc.ps1 -InputPath "./exports/logicapps" -OutputPath "./docs/logicapps"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InputPath = "./exports/logicapps",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./docs/logicapps",
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateDiagrams = $true
)

# Import helper functions
. "$PSScriptRoot/Helpers.ps1"

# Ensure paths exist
if (-not (Test-Path $InputPath)) {
    Write-LogError "Input path does not exist: $InputPath"
    exit 1
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-LogInfo "Created output directory: $OutputPath"
}

# Function to generate individual Logic App documentation
function New-LogicAppDocumentation {
    param(
        [object]$LogicApp,
        [string]$OutputDir
    )
    
    $name = $LogicApp.Name
    Write-LogInfo "Generating documentation for: $name"
    
    # Create sanitized filename
    $fileName = "$(Get-SanitizedFileName -Name $name).md"
    $filePath = Join-Path -Path $OutputDir -ChildPath $fileName
    
    # Start building markdown
    $markdown = @"
# $name

> **Status:** ![Status](https://img.shields.io/badge/Status-$($LogicApp.State)-$(Get-StatusBadgeColor -State $LogicApp.State))  
> **Last Modified:** $($LogicApp.ChangedTime)  
> **Location:** $($LogicApp.Location)

## Overview

| Property | Value |
|----------|-------|
| **Name** | $name |
| **Resource Group** | $($LogicApp.ResourceGroupName) |
| **State** | $($LogicApp.State) |
| **Location** | $($LogicApp.Location) |
| **Created** | $($LogicApp.CreatedTime) |
| **Last Changed** | $($LogicApp.ChangedTime) |
| **Tags** | $(Format-Tags -Tags $LogicApp.Tags) |

## Access Endpoint

``````
$($LogicApp.AccessEndpoint)
``````

---

## 📊 Performance Metrics (Last 30 Days)

"@

    # Add run history if available
    if ($LogicApp.RunHistory) {
        $successRate = Get-RunSuccessRate -RunHistory $LogicApp.RunHistory
        $markdown += @"

| Metric | Count |
|--------|-------|
| **Total Runs** | $($LogicApp.RunHistory.TotalRuns) |
| **✅ Succeeded** | $($LogicApp.RunHistory.Succeeded) |
| **❌ Failed** | $($LogicApp.RunHistory.Failed) |
| **⏸️ Cancelled** | $($LogicApp.RunHistory.Cancelled) |
| **🔄 Running** | $($LogicApp.RunHistory.Running) |
| **Success Rate** | $successRate% |

"@
    }
    else {
        $markdown += "`n*No run history available*`n`n"
    }
    
    $markdown += "---`n`n"
    
    # Add workflow diagram
    if ($GenerateDiagrams) {
        $markdown += @"
## 🔄 Workflow Diagram

``````mermaid
$(New-MermaidDiagram -Workflow $LogicApp)
``````

---

"@
    }
    
    # Add triggers section
    $markdown += @"
## ⚡ Triggers

"@

    if ($LogicApp.Triggers -and $LogicApp.Triggers.Count -gt 0) {
        foreach ($trigger in $LogicApp.Triggers) {
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
    
    $markdown += "`n---`n`n"
    
    # Add actions section
    $markdown += @"
## 🎯 Actions

"@

    if ($LogicApp.Actions -and $LogicApp.Actions.Count -gt 0) {
        $actionNumber = 1
        foreach ($action in $LogicApp.Actions) {
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
    
    $markdown += "`n---`n`n"
    
    # Add connections section (formatted like stefanstranger's logicappdocs)
    $markdown += @"
## Logic App Connections

This section shows an overview of Logic App Workflow connections.

### Connections

"@

    if ($LogicApp.Connections -and $LogicApp.Connections.Count -gt 0) {
        # Create table header
        $markdown += "| ConnectionName | ConnectionId | ConnectionProperties |`n"
        $markdown += "| -------------- | ------------ | -------------------- |`n"
        
        # Add rows
        foreach ($conn in $LogicApp.Connections) {
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
    
    $markdown += "---`n`n"
    
    # Add parameters section
    if ($LogicApp.Parameters -and $LogicApp.Parameters.PSObject.Properties.Count -gt 0) {
        $markdown += @"
## 📋 Parameters

``````json
$($LogicApp.Parameters | ConvertTo-Json -Depth 5)
``````

---

"@
    }
    
    # Add footer
    $markdown += @"
## 📝 Metadata

- **Resource ID:** ``$($LogicApp.Id)``
- **API Version:** $($LogicApp.Version)
- **Documentation Generated:** $(Get-DocumentationTimestamp)

---

## 🔗 Related Resources

- [Azure Portal - Logic App]($($LogicApp.AccessEndpoint))
- [Resource Group: $($LogicApp.ResourceGroupName)](#)

"@

    # Save markdown file
    $markdown | Out-File -FilePath $filePath -Encoding UTF8
    Write-LogSuccess "  Documentation saved to: $filePath"
    
    return @{
        Name = $name
        FileName = $fileName
        FilePath = $filePath
        State = $LogicApp.State
        ResourceGroup = $LogicApp.ResourceGroupName
        TriggerCount = if ($LogicApp.Triggers) { $LogicApp.Triggers.Count } else { 0 }
        ActionCount = if ($LogicApp.Actions) { $LogicApp.Actions.Count } else { 0 }
    }
}

# Main execution
Write-LogInfo "Starting Logic Apps documentation generation..."
Write-LogInfo "Input Path: $InputPath"
Write-LogInfo "Output Path: $OutputPath"

# Find all JSON files
$jsonFiles = Get-ChildItem -Path $InputPath -Filter "*.json" | Where-Object { $_.Name -ne "summary.json" }

if ($jsonFiles.Count -eq 0) {
    Write-LogWarning "No Logic Apps JSON files found in $InputPath"
    exit 0
}

Write-LogInfo "Found $($jsonFiles.Count) Logic App export file(s)"

$documentedApps = @()

# Process each Logic App
foreach ($jsonFile in $jsonFiles) {
    try {
        Write-LogInfo "Processing: $($jsonFile.Name)"
        
        # Read JSON file
        $logicApp = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
        
        # Generate documentation
        $docInfo = New-LogicAppDocumentation -LogicApp $logicApp -OutputDir $OutputPath
        $documentedApps += $docInfo
    }
    catch {
        Write-LogError "Failed to process $($jsonFile.Name): $_"
        Write-LogError $_.ScriptStackTrace
    }
}

# Generate index/README file
Write-LogInfo "Generating index file..."

$indexPath = Join-Path -Path $OutputPath -ChildPath "README.md"
$indexMarkdown = @"
# Logic Apps Documentation

> **Last Updated:** $(Get-DocumentationTimestamp)  
> **Total Logic Apps:** $($documentedApps.Count)

## 📊 Summary

| Metric | Count |
|--------|-------|
| Total Logic Apps | $($documentedApps.Count) |
| Enabled | $(($documentedApps | Where-Object { $_.State -eq 'Enabled' }).Count) |
| Disabled | $(($documentedApps | Where-Object { $_.State -eq 'Disabled' }).Count) |
| Total Triggers | $(($documentedApps | Measure-Object -Property TriggerCount -Sum).Sum) |
| Total Actions | $(($documentedApps | Measure-Object -Property ActionCount -Sum).Sum) |

---

## 📋 Logic Apps Inventory

| Name | Status | Resource Group | Triggers | Actions | Documentation |
|------|--------|----------------|----------|---------|---------------|
"@

foreach ($app in ($documentedApps | Sort-Object Name)) {
    $statusBadge = "![Status](https://img.shields.io/badge/Status-$($app.State)-$(Get-StatusBadgeColor -State $app.State))"
    $indexMarkdown += "| $($app.Name) | $statusBadge | $($app.ResourceGroup) | $($app.TriggerCount) | $($app.ActionCount) | [View](./$($app.FileName)) |`n"
}

$indexMarkdown += @"

---

## 🔍 Quick Links

- [Azure Portal - Logic Apps](https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Logic%2Fworkflows)
- [Microsoft Sentinel Playbooks](https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/WorkspaceSelectorBlade)

---

## 📖 Documentation Guide

Each Logic App has a dedicated documentation page containing:

- ✅ Overview and metadata
- 📊 Performance metrics (30-day run history)
- 🔄 Workflow diagrams (Mermaid)
- ⚡ Trigger configurations
- 🎯 Action details and sequences
- 🔌 API connections and dependencies
- 📋 Parameters and variables

---

## 🔄 Automation

This documentation is automatically generated using:
- **Export Script:** ``scripts/Export-LogicApps.ps1``
- **Generation Script:** ``scripts/Generate-LogicAppsDoc.ps1``
- **GitHub Actions:** ``.github/workflows/logicapps-document.yml``

To manually regenerate documentation:

``````powershell
# Export Logic Apps from Azure
./scripts/Export-LogicApps.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "your-rg"

# Generate documentation
./scripts/Generate-LogicAppsDoc.ps1 -InputPath "./exports/logicapps" -OutputPath "./docs/logicapps"
``````

---

*Generated by Logic Apps Documentation Automation*
"@

$indexMarkdown | Out-File -FilePath $indexPath -Encoding UTF8
Write-LogSuccess "Index file saved to: $indexPath"

Write-LogSuccess "`nDocumentation generation completed successfully!"
Write-LogInfo "Total Logic Apps documented: $($documentedApps.Count)"
Write-LogInfo "Documentation available at: $OutputPath"

# Return summary
return @{
    TotalDocumented = $documentedApps.Count
    OutputPath = $OutputPath
    IndexFile = $indexPath
    DocumentedApps = $documentedApps
}
