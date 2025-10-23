# Setup Guide - Logic Apps Automated Documentation

This guide will help you set up the automated Logic Apps documentation system.

## 📋 Prerequisites

### Required Software
- **PowerShell 7+** or **Windows PowerShell 5.1**
- **Azure PowerShell Module** (`Az`)
- **Git** (for version control)
- **GitHub Account** (for automation)

### Azure Requirements
- **Azure Subscription** with Logic Apps
- **RBAC Permissions**: 
  - `Reader` role minimum (for export)
  - `Logic App Contributor` role (for deployment)
- **Service Principal** or **Managed Identity** (for automation)

## 🚀 Installation Steps

### 1. Install Azure PowerShell Module

```powershell
# Install Az module
Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

# Verify installation
Get-Module -ListAvailable Az
```

### 2. Configure Azure Authentication

#### For Local Development

```powershell
# Interactive login
Connect-AzAccount

# Select subscription
Set-AzContext -SubscriptionId "your-subscription-id"

# Verify context
Get-AzContext
```

#### For GitHub Actions (Service Principal)

Create a service principal with Federated Identity:

```bash
# Azure CLI method
az ad sp create-for-rbac \
  --name "LogicAppsDocumentation" \
  --role "Reader" \
  --scopes "/subscriptions/{subscription-id}" \
  --sdk-auth
```

Or use the Azure Portal to create a service principal with federated credentials for GitHub Actions.

### 3. Configure GitHub Secrets

Add these secrets to your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add the following secrets:

```
AZURE_SENTINEL_CLIENTID_ce5a64466c464a7ba45b506fbf6d77cf
AZURE_SENTINEL_TENANTID_ce5a64466c464a7ba45b506fbf6d77cf
AZURE_SENTINEL_SUBSCRIPTIONID_ce5a64466c464a7ba45b506fbf6d77cf
```

### 4. Grant Service Principal Permissions

```powershell
# Assign Reader role to service principal
New-AzRoleAssignment `
    -ObjectId <service-principal-object-id> `
    -RoleDefinitionName "Reader" `
    -Scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>"
```

### 5. Test Local Execution

```powershell
# Navigate to repository
cd /path/to/repo

# Test export
./scripts/Export-LogicApps.ps1 -ResourceGroupName "training_jordan"

# Test documentation generation
./scripts/Generate-LogicAppsDoc.ps1

# Verify output
ls ./exports/logicapps
ls ./docs/logicapps
```

## 🔧 Configuration

### Customize Workflow Schedule

Edit `.github/workflows/logicapps-document.yml`:

```yaml
on:
  schedule:
    # Examples:
    - cron: '0 6 * * 1'      # Every Monday at 6 AM
    - cron: '0 0 * * *'      # Daily at midnight
    - cron: '0 */6 * * *'    # Every 6 hours
```

### Configure Export Parameters

Edit default values in `Export-LogicApps.ps1`:

```powershell
param(
    [int]$RunHistoryDays = 30,  # Change default history window
    [string]$OutputPath = "./exports/logicapps"
)
```

### Exclude Files from Deployment

Edit `sentinel-deployment.config`:

```json
{
  "excludecontentfiles": [
    "test",
    ".github/",
    "scripts/",
    "exports/",
    "docs/"
  ]
}
```

## ✅ Verification

### Test GitHub Actions Workflow

1. Go to **Actions** tab in GitHub
2. Select **Logic Apps Documentation Generator**
3. Click **Run workflow**
4. Monitor execution in real-time
5. Check for PR creation
6. Review PR and merge

### Verify Documentation Output

Expected structure:

```
docs/
└── logicapps/
    ├── README.md                  # Index with inventory
    ├── playbook1.md              # Individual docs
    ├── playbook2.md
    └── .gitkeep
```

Each file should contain:
- ✅ Overview section
- ✅ Performance metrics
- ✅ Mermaid diagrams
- ✅ Trigger details
- ✅ Action breakdown
- ✅ Connections

## 🔍 Troubleshooting

### Issue: "Connect-AzAccount: The term 'Connect-AzAccount' is not recognized"

**Solution:**
```powershell
Install-Module -Name Az -Force -AllowClobber
Import-Module Az
```

### Issue: "Insufficient permissions to export Logic Apps"

**Solution:**
- Verify you have `Reader` role on subscription/resource group
- Check with: `Get-AzRoleAssignment -SignInName your@email.com`
- Request permissions from Azure administrator

### Issue: "GitHub Actions authentication failed"

**Solution:**
1. Verify GitHub secrets are correctly named
2. Check service principal credentials are valid
3. Ensure federated identity is configured for GitHub
4. Test authentication locally with service principal

### Issue: "No Logic Apps found during export"

**Solution:**
1. Verify Logic Apps exist in specified resource group
2. Check subscription context: `Get-AzContext`
3. Confirm resource group name spelling
4. Try exporting from all resource groups (omit `-ResourceGroupName`)

### Issue: "Mermaid diagrams not rendering"

**Solution:**
- View documentation on GitHub (native Mermaid support)
- Use VS Code with "Markdown Preview Mermaid Support" extension
- Use online Mermaid viewer: https://mermaid.live/

## 🔒 Security Best Practices

### 1. Principle of Least Privilege
- Use `Reader` role for documentation (not Contributor)
- Create separate service principals for different tasks
- Limit scope to specific resource groups when possible

### 2. Secret Management
- Never commit secrets to repository
- Use GitHub Secrets for sensitive data
- Rotate service principal credentials regularly
- Use managed identities when possible (Azure-hosted runners)

### 3. Review Process
- Always review auto-generated PRs before merging
- Check for exposed secrets or sensitive data
- Validate documentation accuracy
- Enable branch protection rules

### 4. Audit Logging
- Monitor service principal usage in Azure
- Review GitHub Actions logs regularly
- Enable Azure Activity Log for Logic Apps access

## 📚 Additional Resources

### Official Documentation
- [Azure Logic Apps](https://docs.microsoft.com/azure/logic-apps/)
- [GitHub Actions - Azure Login](https://github.com/marketplace/actions/azure-login)
- [Azure PowerShell Documentation](https://docs.microsoft.com/powershell/azure/)

### Useful Links
- [Mermaid Diagram Syntax](https://mermaid.js.org/syntax/flowchart.html)
- [GitHub Actions OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Microsoft Sentinel Playbooks](https://docs.microsoft.com/azure/sentinel/automate-responses-with-playbooks)

## 🆘 Support

### Getting Help

1. **Check logs**: Review GitHub Actions logs for errors
2. **Test locally**: Run scripts manually to isolate issues
3. **Review documentation**: Check this guide and README files
4. **Azure support**: For Azure-specific issues, contact Azure support

### Common Commands

```powershell
# Check Azure connection
Get-AzContext

# List all Logic Apps
Get-AzLogicApp

# Get specific Logic App details
Get-AzLogicApp -ResourceGroupName "training_jordan" -Name "YourPlaybookName"

# Test script syntax
Test-ScriptFileInfo -Path ./scripts/Export-LogicApps.ps1

# Enable verbose output
./scripts/Export-LogicApps.ps1 -Verbose
```

## 🎯 Next Steps

After setup:

1. ✅ Run initial export and documentation generation
2. ✅ Review generated documentation for accuracy
3. ✅ Test GitHub Actions workflow
4. ✅ Set up branch protection rules
5. ✅ Schedule regular review of documentation updates
6. ✅ Train team members on using the system

---

**Setup Complete!** 🎉

Your automated Logic Apps documentation system is now ready to use.

*Last Updated: 2025-10-22*
