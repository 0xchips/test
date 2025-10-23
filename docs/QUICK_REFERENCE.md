# Logic Apps Documentation - Quick Reference

## 🎯 Quick Commands

### Export Logic Apps
```powershell
# From specific resource group
./scripts/Export-LogicApps.ps1 -ResourceGroupName "training_jordan"

# From all resource groups in current subscription
./scripts/Export-LogicApps.ps1

# With custom parameters
./scripts/Export-LogicApps.ps1 `
    -SubscriptionId "your-sub-id" `
    -ResourceGroupName "training_jordan" `
    -OutputPath "./exports/logicapps" `
    -RunHistoryDays 60
```

### Generate Documentation
```powershell
# Standard generation
./scripts/Generate-LogicAppsDoc.ps1

# Custom paths
./scripts/Generate-LogicAppsDoc.ps1 `
    -InputPath "./exports/logicapps" `
    -OutputPath "./docs/logicapps"

# Without diagrams
./scripts/Generate-LogicAppsDoc.ps1 -GenerateDiagrams:$false
```

### Full Pipeline
```powershell
# Export and document in one go
./scripts/Export-LogicApps.ps1 -ResourceGroupName "training_jordan"
./scripts/Generate-LogicAppsDoc.ps1
```

## 📊 Viewing Documentation

1. Navigate to `docs/logicapps/`
2. Open `README.md` for the inventory
3. Click on individual Logic App links
4. View Mermaid diagrams in GitHub or VS Code with Mermaid extension

## 🔄 Automation Workflow

### Scheduled Run
- Runs every Monday at 6 AM UTC
- Automatically creates a PR with changes
- Review and merge the PR to update documentation

### Manual Run
1. Go to GitHub Actions
2. Select "Logic Apps Documentation Generator"
3. Click "Run workflow"
4. Optionally specify resource group
5. Wait for PR to be created

## 🛠️ Maintenance

### Update Schedule
Edit `.github/workflows/logicapps-document.yml`:
```yaml
on:
  schedule:
    - cron: '0 6 * * 1'  # Change this
```

### Add New Logic Apps
1. Deploy Logic App to Azure
2. Run export script or wait for scheduled run
3. Documentation will be auto-generated

### Exclude Logic Apps
Edit `sentinel-deployment.config` to exclude specific apps from deployment (not documentation).

## 🔍 Troubleshooting

### "No Logic Apps found"
- Check subscription and resource group
- Verify Azure permissions (Reader role minimum)
- Ensure you're authenticated: `Connect-AzAccount`

### "Failed to export"
- Check network connectivity to Azure
- Verify subscription access
- Review error messages in output

### Documentation not rendering diagrams
- Ensure viewing in GitHub or with Mermaid-enabled editor
- Check Mermaid syntax in generated files
- Use VS Code with "Markdown Preview Mermaid Support" extension

## 📝 Best Practices

1. **Review PRs**: Always review auto-generated documentation PRs for sensitive data
2. **Regular Updates**: Keep documentation in sync with Azure (weekly recommended)
3. **Version Control**: Keep old documentation versions in git history
4. **Security**: Never commit connection strings or secrets
5. **Testing**: Test export locally before relying on automation

## 🔗 Resources

- [Main README](../README.md)
- [Scripts Documentation](../scripts/)
- [Azure Logic Apps Docs](https://docs.microsoft.com/azure/logic-apps/)

---

*Last Updated: 2025-10-22*
