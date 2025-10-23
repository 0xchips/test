<#
.SYNOPSIS
    Exports all Logic Apps from Azure tenant for documentation purposes.

.DESCRIPTION
    This script discovers and exports all Logic Apps (workflows) from the specified 
    Azure subscription and resource group. It retrieves workflow definitions, 
    trigger configurations, actions, connections, and run history.

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER ResourceGroupName
    Resource Group name (optional - if not specified, scans all resource groups)

.PARAMETER OutputPath
    Path where exported Logic Apps JSON files will be saved

.EXAMPLE
    .\Export-LogicApps.ps1 -SubscriptionId "xxx" -ResourceGroupName "training_jordan" -OutputPath "./exports"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./exports/logicapps",
    
    [Parameter(Mandatory = $false)]
    [int]$RunHistoryDays = 30
)

# Import helper functions
. "$PSScriptRoot/Helpers.ps1"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-LogInfo "Created output directory: $OutputPath"
}

# Get current context if not specified
if (-not $SubscriptionId) {
    $context = Get-AzContext
    if (-not $context) {
        Write-LogError "No Azure context found. Please run Connect-AzAccount first."
        exit 1
    }
    $SubscriptionId = $context.Subscription.Id
    Write-LogInfo "Using current subscription: $($context.Subscription.Name) ($SubscriptionId)"
}

# Set subscription context
try {
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
    Write-LogInfo "Set Azure context to subscription: $SubscriptionId"
}
catch {
    Write-LogError "Failed to set Azure context: $_"
    exit 1
}

# Function to get Logic Apps from resource group
function Get-LogicAppsFromResourceGroup {
    param(
        [string]$RgName
    )
    
    Write-LogInfo "Scanning resource group: $RgName"
    
    try {
        $workflows = Get-AzLogicApp -ResourceGroupName $RgName -ErrorAction Stop
        return $workflows
    }
    catch {
        Write-LogWarning "Failed to get Logic Apps from resource group $RgName : $_"
        return @()
    }
}

# Function to get workflow run history
function Get-WorkflowRunHistory {
    param(
        [string]$ResourceGroupName,
        [string]$WorkflowName,
        [int]$Days
    )
    
    try {
        $startTime = (Get-Date).AddDays(-$Days)
        $runs = Get-AzLogicAppRunHistory -ResourceGroupName $ResourceGroupName -Name $WorkflowName -ErrorAction Stop | 
                Where-Object { $_.StartTime -gt $startTime }
        
        $stats = @{
            TotalRuns = $runs.Count
            Succeeded = ($runs | Where-Object { $_.Status -eq 'Succeeded' }).Count
            Failed = ($runs | Where-Object { $_.Status -eq 'Failed' }).Count
            Cancelled = ($runs | Where-Object { $_.Status -eq 'Cancelled' }).Count
            Running = ($runs | Where-Object { $_.Status -eq 'Running' }).Count
        }
        
        return $stats
    }
    catch {
        Write-LogWarning "Failed to get run history for $WorkflowName : $_"
        return $null
    }
}

# Function to get workflow connections
function Get-WorkflowConnections {
    param(
        [object]$WorkflowDefinition
    )
    
    $connections = @()
    
    if ($WorkflowDefinition.definition.parameters.'$connections'.value) {
        $connectionParams = $WorkflowDefinition.definition.parameters.'$connections'.value
        
        foreach ($connName in $connectionParams.PSObject.Properties.Name) {
            $conn = $connectionParams.$connName
            $connections += @{
                Name = $connName
                ConnectionId = $conn.connectionId
                ConnectionName = $conn.connectionName
                Id = $conn.id
            }
        }
    }
    
    return $connections
}

# Function to extract trigger information
function Get-TriggerInfo {
    param(
        [object]$WorkflowDefinition
    )
    
    $triggers = @()
    
    if ($WorkflowDefinition.definition.triggers) {
        foreach ($triggerName in $WorkflowDefinition.definition.triggers.PSObject.Properties.Name) {
            $trigger = $WorkflowDefinition.definition.triggers.$triggerName
            
            $triggerInfo = @{
                Name = $triggerName
                Type = $trigger.type
                Recurrence = $null
                Conditions = $null
            }
            
            if ($trigger.recurrence) {
                $triggerInfo.Recurrence = @{
                    Frequency = $trigger.recurrence.frequency
                    Interval = $trigger.recurrence.interval
                }
            }
            
            if ($trigger.inputs) {
                $triggerInfo.Conditions = $trigger.inputs
            }
            
            $triggers += $triggerInfo
        }
    }
    
    return $triggers
}

# Function to extract action information
function Get-ActionInfo {
    param(
        [object]$WorkflowDefinition
    )
    
    $actions = @()
    
    if ($WorkflowDefinition.definition.actions) {
        foreach ($actionName in $WorkflowDefinition.definition.actions.PSObject.Properties.Name) {
            $action = $WorkflowDefinition.definition.actions.$actionName
            
            $actionInfo = @{
                Name = $actionName
                Type = $action.type
                RunAfter = $action.runAfter
                Inputs = if ($action.inputs) { $action.inputs } else { $null }
            }
            
            $actions += $actionInfo
        }
    }
    
    return $actions
}

# Main execution
Write-LogInfo "Starting Logic Apps export process..."
Write-LogInfo "Parameters: SubscriptionId=$SubscriptionId, ResourceGroup=$ResourceGroupName, OutputPath=$OutputPath"

$allLogicApps = @()

# Get Logic Apps
if ($ResourceGroupName) {
    # Scan specific resource group
    $workflows = Get-LogicAppsFromResourceGroup -RgName $ResourceGroupName
}
else {
    # Scan all resource groups
    Write-LogInfo "No resource group specified, scanning all resource groups in subscription..."
    $resourceGroups = Get-AzResourceGroup
    
    $workflows = @()
    foreach ($rg in $resourceGroups) {
        $rgWorkflows = Get-LogicAppsFromResourceGroup -RgName $rg.ResourceGroupName
        $workflows += $rgWorkflows
    }
}

Write-LogInfo "Found $($workflows.Count) Logic App(s)"

# Process each Logic App
foreach ($workflow in $workflows) {
    Write-LogInfo "Processing Logic App: $($workflow.Name)"
    
    try {
        # Get full workflow definition
        $workflowDef = Get-AzLogicApp -ResourceGroupName $workflow.ResourceGroupName -Name $workflow.Name
        
        # Get run history
        Write-LogInfo "  Retrieving run history (last $RunHistoryDays days)..."
        $runStats = Get-WorkflowRunHistory -ResourceGroupName $workflow.ResourceGroupName -WorkflowName $workflow.Name -Days $RunHistoryDays
        
        # Extract connections
        Write-LogInfo "  Extracting connections..."
        $connections = Get-WorkflowConnections -WorkflowDefinition $workflowDef
        
        # Extract triggers
        Write-LogInfo "  Extracting triggers..."
        $triggers = Get-TriggerInfo -WorkflowDefinition $workflowDef
        
        # Extract actions
        Write-LogInfo "  Extracting actions..."
        $actions = Get-ActionInfo -WorkflowDefinition $workflowDef
        
        # Build comprehensive Logic App information
        $logicAppInfo = @{
            Name = $workflow.Name
            ResourceGroupName = $workflow.ResourceGroupName
            Location = $workflow.Location
            State = $workflow.State
            Id = $workflow.Id
            CreatedTime = $workflow.CreatedTime
            ChangedTime = $workflow.ChangedTime
            Version = $workflow.Version
            AccessEndpoint = $workflow.AccessEndpoint
            Definition = $workflowDef.Definition
            Parameters = $workflowDef.Parameters
            Triggers = $triggers
            Actions = $actions
            Connections = $connections
            RunHistory = $runStats
            Tags = $workflow.Tags
            ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Save to JSON file
        $fileName = "$($workflow.Name).json"
        $filePath = Join-Path -Path $OutputPath -ChildPath $fileName
        $logicAppInfo | ConvertTo-Json -Depth 20 | Out-File -FilePath $filePath -Encoding UTF8
        
        Write-LogSuccess "  Exported to: $filePath"
        
        $allLogicApps += $logicAppInfo
    }
    catch {
        Write-LogError "Failed to process Logic App $($workflow.Name): $_"
        Write-LogError $_.ScriptStackTrace
    }
}

# Create summary file
$summary = @{
    ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SubscriptionId = $SubscriptionId
    ResourceGroupName = if ($ResourceGroupName) { $ResourceGroupName } else { "All" }
    TotalLogicApps = $allLogicApps.Count
    LogicApps = $allLogicApps | Select-Object Name, ResourceGroupName, State, Location
}

$summaryPath = Join-Path -Path $OutputPath -ChildPath "summary.json"
$summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding UTF8

Write-LogSuccess "`nExport completed successfully!"
Write-LogInfo "Total Logic Apps exported: $($allLogicApps.Count)"
Write-LogInfo "Summary file: $summaryPath"
Write-LogInfo "Individual files location: $OutputPath"

# Return summary for pipeline usage
return $summary
