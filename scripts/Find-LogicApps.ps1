<#
.SYNOPSIS
    Quick script to find and list Logic Apps in your subscription

.DESCRIPTION
    Lists all Logic Apps to help you identify the correct name and resource group
#>

Write-Host "`n🔍 Searching for Logic Apps in your subscription...`n" -ForegroundColor Cyan

try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "❌ Not connected to Azure. Please run: Connect-AzAccount" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Connected to: $($context.Subscription.Name)`n" -ForegroundColor Green
    
    Write-Host "📋 Finding all Logic Apps..." -ForegroundColor Cyan
    $logicApps = Get-AzLogicApp
    
    if ($logicApps.Count -eq 0) {
        Write-Host "⚠️  No Logic Apps found in this subscription" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "✅ Found $($logicApps.Count) Logic App(s)`n" -ForegroundColor Green
    
    # Display in a nice table
    $logicApps | Select-Object `
        @{N='Name';E={$_.Name}},
        @{N='Resource Group';E={$_.ResourceGroupName}},
        @{N='State';E={$_.State}},
        @{N='Location';E={$_.Location}} |
        Format-Table -AutoSize
    
    # Check for the specific Logic App
    $targetName = "MULTI-EmailReportedResults-Prod-00010"
    $found = $logicApps | Where-Object { $_.Name -eq $targetName }
    
    if ($found) {
        Write-Host "`n✅ Found your Logic App: $targetName" -ForegroundColor Green
        Write-Host "   Resource Group: $($found.ResourceGroupName)" -ForegroundColor Cyan
        Write-Host "   State: $($found.State)" -ForegroundColor Cyan
        Write-Host "`n📝 To test documentation, run:" -ForegroundColor Yellow
        Write-Host "   pwsh -File ./scripts/Test-SingleLogicApp.ps1 -LogicAppName '$targetName' -ResourceGroupName '$($found.ResourceGroupName)'" -ForegroundColor White
    }
    else {
        Write-Host "`n⚠️  Logic App '$targetName' not found" -ForegroundColor Yellow
        Write-Host "   Please use one of the names from the table above" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host ""
