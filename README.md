# Logic Apps Automated Documentation

[![Documentation Status](https://img.shields.io/badge/Documentation-Automated-brightgreen)](./docs/logicapps)
[![Last Updated](https://img.shields.io/badge/Last%20Updated-See%20Docs-blue)](./docs/logicapps)

This repository provides automated documentation for Azure Logic Apps (Playbooks) used in Microsoft Sentinel and other Azure services.

## 🎯 Overview

This solution automatically:
- 📥 **Exports** all Logic Apps from your Azure tenant
- 📝 **Generates** comprehensive markdown documentation
- 📊 **Visualizes** workflows with Mermaid diagrams
- 📈 **Tracks** performance metrics and run history
- 🔄 **Updates** documentation on a schedule via GitHub Actions

## 📁 Repository Structure

```
├── .github/workflows/
│   ├── logicapps-document.yml      # Documentation automation workflow
│   └── sentinel-deploy-*.yml       # Sentinel deployment workflows
├── scripts/
│   ├── Export-LogicApps.ps1        # Azure Logic Apps export script
│   ├── Generate-LogicAppsDoc.ps1   # Documentation generator
│   └── Helpers.ps1                 # Shared utility functions
├── docs/
│   └── logicapps/
│       ├── README.md               # Logic Apps inventory
│       └── *.md                    # Individual Logic App docs
├── playbooks/                      # Logic Apps ARM templates
└── exports/                        # Exported JSON (gitignored)
```

## 🚀 Quick Start

### Prerequisites

- Azure subscription with Logic Apps
- Azure CLI or PowerShell with Az module
- Appropriate Azure RBAC permissions (Reader minimum)
- GitHub repository secrets configured (for automation)

### Manual Documentation Generation

1. **Export Logic Apps from Azure:**

```powershell
# Export from specific resource group
./scripts/Export-LogicApps.ps1 `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "training_jordan" `
    -OutputPath "./exports/logicapps"

# Export from all resource groups
./scripts/Export-LogicApps.ps1 `
    -SubscriptionId "your-subscription-id" `
    -OutputPath "./exports/logicapps"
```

2. **Generate Documentation:**

```powershell
./scripts/Generate-LogicAppsDoc.ps1 `
    -InputPath "./exports/logicapps" `
    -OutputPath "./docs/logicapps"
```

3. **View Documentation:**

Open `./docs/logicapps/README.md` to see the inventory and navigate to individual Logic App documentation.

## 📚 Documentation Features

Each generated Logic App documentation includes:

- ✅ **Overview Section**: Status badge, resource metadata, tags, creation dates, access endpoint
- 📊 **Performance Metrics**: Last 30 days run history, success/failure statistics, success rate
- 🔄 **Workflow Visualization**: Mermaid diagrams showing Trigger → Actions → End flow
- ⚡ **Trigger Details**: Trigger type, configuration, recurrence schedules, webhook details
- 🎯 **Action Breakdown**: Step-by-step listing with types, dependencies (runAfter), inputs/outputs
- 🔌 **Connections**: API connections table with connection names, IDs, and properties

Format matches industry standard: [stefanstranger/logicappdocs](https://github.com/stefanstranger/logicappdocs)

### Automated Documentation (GitHub Actions)

The workflow is **currently disabled**. To enable weekly automated documentation:

1. Edit `.github/workflows/logicapps-document.yml`
2. Uncomment the schedule section:
   ```yaml
   schedule:
     - cron: '0 8 * * 1'  # Run every Monday at 8 AM UTC
   ```
3. Commit and push the changes

#### Manual Workflow Execution

You can run the workflow manually for:
- **All Logic Apps:** Leave all inputs empty
- **Specific Resource Group:** Enter resource group name (default: `training_jordan`)
- **Specific Subscription:** Enter subscription ID (uses Acme Insurance subscription by default)
- **Single Logic App:** Enter both resource group and Logic App name

To trigger manually:
1. Go to **Actions** → **Logic Apps Documentation Generator**
2. Click **Run workflow**
3. Fill in the parameters:
   - **Resource Group**: `training_jordan` (or your resource group)
   - **Subscription ID**: Leave empty for default or specify custom
   - **Logic App Name**: Leave empty for all, or specify one (e.g., `MULTI-EmailReportedResults-Prod-00010`)
4. Click **Run workflow**
5. Review the auto-generated Pull Request

#### Change Detection

The workflow automatically:
- ✅ Checks for changes in Logic App definitions
- ✅ Detects new or removed Logic Apps
- ✅ Updates documentation only when changes are found
- ✅ Creates a Pull Request for review before merging

## 📖 Usage Examples

### Example 1: Export All Logic Apps from Training Jordan

```powershell
# Export all Logic Apps from training_jordan resource group
./scripts/Export-LogicApps.ps1 `
    -SubscriptionId "5cfeafdb-fc6b-4d09-971d-3320c5ec14a0" `
    -ResourceGroupName "training_jordan" `
    -OutputPath "./exports/logicapps"

# Generate documentation
./scripts/Generate-LogicAppsDoc.ps1 `
    -InputPath "./exports/logicapps" `
    -OutputPath "./docs/logicapps"
```

### Example 2: Document a Specific Logic App

```powershell
# Test and document a single Logic App
./scripts/Test-SingleLogicApp.ps1 `
    -LogicAppName "MULTI-EmailReportedResults-Prod-00010" `
    -ResourceGroupName "training_jordan"

# Output will be in:
# - ./exports/test/logicapps/MULTI-EmailReportedResults-Prod-00010.json
# - ./exports/test/docs/MULTI-EmailReportedResults-Prod-00010.md
```

### Example 3: Document Logic Apps from Playbooks-Sentinel

```powershell
# Export all Sentinel playbooks
./scripts/Export-LogicApps.ps1 `
    -SubscriptionId "712c68d2-ad83-4d87-8c08-ef13209fe469" `
    -ResourceGroupName "Playbooks-Sentinel" `
    -OutputPath "./exports/logicapps"
```

### Example 4: Using as a Tool for Different Subscriptions

```powershell
# For Acme Insurance subscription (training_jordan)
$acmeParams = @{
    SubscriptionId = "5cfeafdb-fc6b-4d09-971d-3320c5ec14a0"
    ResourceGroupName = "training_jordan"
    OutputPath = "./exports/acme"
}
./scripts/Export-LogicApps.ps1 @acmeParams

# For Wizard Cyber subscription (Playbooks-Sentinel)
$wizardParams = @{
    SubscriptionId = "712c68d2-ad83-4d87-8c08-ef13209fe469"
    ResourceGroupName = "Playbooks-Sentinel"
    OutputPath = "./exports/wizard"
}
./scripts/Export-LogicApps.ps1 @wizardParams
```

## 🔗 Related Resources

- [Azure Logic Apps Documentation](https://docs.microsoft.com/azure/logic-apps/)
- [Microsoft Sentinel Playbooks](https://docs.microsoft.com/azure/sentinel/automate-responses-with-playbooks)
- [Mermaid Diagram Syntax](https://mermaid.js.org/)
- [stefanstranger/logicappdocs](https://github.com/stefanstranger/logicappdocs) - Inspiration for documentation format

---

**Maintained by:** Azure Sentinel Team  
**Last Updated:** 2025-10-23  
**Status:** ✅ Active
