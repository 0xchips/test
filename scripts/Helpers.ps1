<#
.SYNOPSIS
    Helper functions for Logic Apps documentation automation

.DESCRIPTION
    Shared utility functions for logging, formatting, and common operations
#>

# Color-coded logging functions
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to sanitize names for file paths
function Get-SanitizedFileName {
    param(
        [string]$Name
    )
    
    $sanitized = $Name -replace '[^\w\-]', '_'
    return $sanitized
}

# Function to format JSON for better readability
function Format-JsonOutput {
    param(
        [object]$Object,
        [int]$Depth = 10
    )
    
    return $Object | ConvertTo-Json -Depth $Depth
}

# Function to generate Mermaid diagram code for workflow
function New-MermaidDiagram {
    param(
        [object]$Workflow
    )
    
    $diagram = @"
graph TD
    Start([Start]) --> Trigger{Trigger}
"@

    # Add trigger
    if ($Workflow.Triggers -and $Workflow.Triggers.Count -gt 0) {
        foreach ($trigger in $Workflow.Triggers) {
            $triggerNode = "T_$($trigger.Name -replace '[^\w]', '_')"
            # Sanitize label - replace pipes and other special characters
            $triggerLabel = $trigger.Name -replace '\|', '-' -replace '[<>{}"]', ''
            $diagram += "`n    Trigger --> $triggerNode[$triggerLabel]"
        }
    }
    
    # Add actions
    if ($Workflow.Actions -and $Workflow.Actions.Count -gt 0) {
        $previousNode = if ($Workflow.Triggers.Count -gt 0) { "T_$($Workflow.Triggers[0].Name -replace '[^\w]', '_')" } else { "Trigger" }
        
        foreach ($action in $Workflow.Actions) {
            $actionNode = "A_$($action.Name -replace '[^\w]', '_')"
            # Sanitize label - replace pipes and other special characters
            $actionLabel = $action.Name -replace '\|', '-' -replace '[<>{}"]', ''
            
            # Determine shape based on action type
            $nodeShape = switch -Wildcard ($action.Type) {
                "*Condition*" { "{$actionLabel}" }
                "*Switch*" { "{$actionLabel}" }
                "*Foreach*" { "[$actionLabel]" }
                "*Until*" { "[$actionLabel]" }
                default { "($actionLabel)" }
            }
            
            $diagram += "`n    $previousNode --> $actionNode$nodeShape"
            $previousNode = $actionNode
        }
        
        $diagram += "`n    $previousNode --> End([End])"
    }
    else {
        $diagram += "`n    Trigger --> End([End])"
    }
    
    return $diagram
}

# Function to extract tags as formatted string
function Format-Tags {
    param(
        [object]$Tags
    )
    
    if (-not $Tags) {
        return "None"
    }
    
    $tagStrings = @()
    foreach ($key in $Tags.PSObject.Properties.Name) {
        $tagStrings += "$key`: $($Tags.$key)"
    }
    
    return $tagStrings -join ", "
}

# Function to format recurrence schedule
function Format-RecurrenceSchedule {
    param(
        [object]$Recurrence
    )
    
    if (-not $Recurrence) {
        return "Not configured"
    }
    
    $interval = $Recurrence.Interval
    $frequency = $Recurrence.Frequency
    
    return "Every $interval $frequency"
}

# Function to determine trigger type display name
function Get-TriggerTypeDisplayName {
    param(
        [string]$Type
    )
    
    $displayNames = @{
        "Recurrence" = "⏰ Scheduled (Recurrence)"
        "Request" = "🌐 HTTP Request"
        "ApiConnection" = "🔌 API Connection"
        "ApiConnectionWebhook" = "🪝 Webhook"
        "HttpWebhook" = "🪝 HTTP Webhook"
        "Http" = "🌐 HTTP"
    }
    
    if ($displayNames.ContainsKey($Type)) {
        return $displayNames[$Type]
    }
    else {
        return $Type
    }
}

# Function to determine action type display name
function Get-ActionTypeDisplayName {
    param(
        [string]$Type
    )
    
    $displayNames = @{
        "Http" = "🌐 HTTP Request"
        "ApiConnection" = "🔌 API Connection"
        "Compose" = "📝 Compose"
        "InitializeVariable" = "💾 Initialize Variable"
        "SetVariable" = "💾 Set Variable"
        "IncrementVariable" = "➕ Increment Variable"
        "AppendToArrayVariable" = "📋 Append to Array"
        "Condition" = "❓ Condition"
        "Switch" = "🔀 Switch"
        "Foreach" = "🔁 For Each"
        "Until" = "🔁 Until"
        "ParseJson" = "📄 Parse JSON"
        "Response" = "↩️ Response"
        "Terminate" = "🛑 Terminate"
    }
    
    if ($displayNames.ContainsKey($Type)) {
        return $displayNames[$Type]
    }
    else {
        return "⚙️ $Type"
    }
}

# Function to calculate run success rate
function Get-RunSuccessRate {
    param(
        [object]$RunHistory
    )
    
    if (-not $RunHistory -or $RunHistory.TotalRuns -eq 0) {
        return "N/A"
    }
    
    $successRate = ($RunHistory.Succeeded / $RunHistory.TotalRuns) * 100
    return [math]::Round($successRate, 2)
}

# Function to generate status badge color
function Get-StatusBadgeColor {
    param(
        [string]$State
    )
    
    switch ($State) {
        "Enabled" { return "brightgreen" }
        "Disabled" { return "red" }
        "Suspended" { return "orange" }
        default { return "lightgrey" }
    }
}

# Function to create markdown table from array of objects
function New-MarkdownTable {
    param(
        [array]$Data,
        [array]$Columns
    )
    
    if ($Data.Count -eq 0) {
        return "No data available"
    }
    
    # Header
    $table = "| " + ($Columns -join " | ") + " |`n"
    $table += "| " + (($Columns | ForEach-Object { "---" }) -join " | ") + " |`n"
    
    # Rows
    foreach ($item in $Data) {
        $row = "| "
        foreach ($col in $Columns) {
            $value = if ($item.$col) { $item.$col } else { "" }
            $row += "$value | "
        }
        $table += $row + "`n"
    }
    
    return $table
}

# Function to escape markdown special characters
function Escape-Markdown {
    param(
        [string]$Text
    )
    
    if (-not $Text) {
        return ""
    }
    
    return $Text -replace '([\\`*_{}[\]()#+\-.!])', '\$1'
}

# Function to format file size
function Format-FileSize {
    param(
        [long]$Bytes
    )
    
    if ($Bytes -lt 1KB) {
        return "$Bytes B"
    }
    elseif ($Bytes -lt 1MB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    elseif ($Bytes -lt 1GB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    else {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
}

# Function to create a documentation timestamp
function Get-DocumentationTimestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC
}

# Note: Functions are available when dot-sourced
# No Export-ModuleMember needed when using dot-sourcing
