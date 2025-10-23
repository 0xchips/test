# Logic Apps Documentation - Architecture

This document explains the architecture and workflow of the automated Logic Apps documentation system.

## 🏗️ System Architecture

```mermaid
graph TB
    subgraph "Azure Environment"
        LA[Logic Apps/Playbooks]
        RG[Resource Groups]
        SUB[Subscription]
    end
    
    subgraph "GitHub Repository"
        GHA[GitHub Actions Workflow]
        SCRIPTS[PowerShell Scripts]
        EXPORTS[Exports Directory]
        DOCS[Docs Directory]
    end
    
    subgraph "Documentation Process"
        EXPORT[Export Script]
        GEN[Generator Script]
        MD[Markdown Files]
    end
    
    LA --> EXPORT
    RG --> EXPORT
    SUB --> EXPORT
    
    GHA --> EXPORT
    EXPORT --> EXPORTS
    EXPORTS --> GEN
    GEN --> MD
    MD --> DOCS
    
    DOCS --> PR[Pull Request]
    PR --> REVIEW{Review}
    REVIEW -->|Approved| MERGE[Merge to Main]
    REVIEW -->|Changes Needed| UPDATE[Update PR]
```

## 📊 Data Flow

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant Azure as Azure API
    participant Export as Export Script
    participant FS as File System
    participant Gen as Generator
    participant Docs as Documentation

    GH->>Azure: Authenticate (OIDC)
    GH->>Export: Run Export-LogicApps.ps1
    Export->>Azure: Get Logic Apps List
    Azure-->>Export: Return Logic Apps
    
    loop For each Logic App
        Export->>Azure: Get Workflow Details
        Export->>Azure: Get Run History
        Export->>Azure: Get Connections
        Azure-->>Export: Return Details
    end
    
    Export->>FS: Save JSON files
    FS-->>Export: Confirm save
    
    GH->>Gen: Run Generate-LogicAppsDoc.ps1
    Gen->>FS: Read JSON files
    FS-->>Gen: Return data
    
    loop For each Logic App
        Gen->>Gen: Generate Markdown
        Gen->>Gen: Create Diagrams
        Gen->>Docs: Save .md file
    end
    
    Gen->>Docs: Create README index
    GH->>GH: Create Pull Request
```

## 🔄 Workflow Components

### 1. GitHub Actions Workflow
**File:** `.github/workflows/logicapps-document.yml`

```mermaid
graph LR
    A[Schedule/Manual Trigger] --> B[Azure Login]
    B --> C[Export Logic Apps]
    C --> D[Generate Docs]
    D --> E[Check Changes]
    E -->|Changes Found| F[Create PR]
    E -->|No Changes| G[Skip]
    F --> H[Upload Artifacts]
```

**Features:**
- Scheduled execution (cron)
- Manual trigger with parameters
- Retry logic for Azure authentication
- Automatic PR creation
- Artifact upload for review

### 2. Export Script
**File:** `scripts/Export-LogicApps.ps1`

**Responsibilities:**
- Connect to Azure subscription
- Enumerate Logic Apps in scope
- Extract workflow definitions
- Retrieve run history statistics
- Identify connections and dependencies
- Export to JSON format

**Output:** JSON files in `exports/logicapps/`

### 3. Generator Script
**File:** `scripts/Generate-LogicAppsDoc.ps1`

**Responsibilities:**
- Read exported JSON files
- Generate markdown documentation
- Create Mermaid workflow diagrams
- Build inventory/index page
- Format metrics and statistics

**Output:** Markdown files in `docs/logicapps/`

### 4. Helper Functions
**File:** `scripts/Helpers.ps1`

**Provides:**
- Logging utilities (colored output)
- Mermaid diagram generation
- Markdown formatting helpers
- Badge generation
- Data transformation functions

## 📁 Directory Structure

```
test/
├── .github/
│   └── workflows/
│       ├── logicapps-document.yml          # Documentation workflow
│       └── sentinel-deploy-*.yml           # Deployment workflow
│
├── scripts/
│   ├── Export-LogicApps.ps1               # Azure export logic
│   ├── Generate-LogicAppsDoc.ps1          # Documentation generator
│   ├── Deploy-Sentinel.ps1                # Deployment script
│   └── Helpers.ps1                        # Shared utilities
│
├── docs/
│   ├── logicapps/                         # Generated documentation
│   │   ├── README.md                      # Auto-generated index
│   │   └── *.md                           # Individual Logic App docs
│   ├── diagrams/                          # Custom diagrams (if needed)
│   ├── SETUP_GUIDE.md                     # Setup instructions
│   └── QUICK_REFERENCE.md                 # Quick commands
│
├── playbooks/                             # Logic Apps ARM templates
│   └── example-playbook.json              # Example template
│
├── exports/                               # Export data (gitignored)
│   └── logicapps/
│       ├── *.json                         # Individual Logic App exports
│       └── summary.json                   # Export summary
│
├── .gitignore                             # Git ignore rules
├── sentinel-deployment.config             # Deployment configuration
└── README.md                              # Main documentation
```

## 🔐 Security Architecture

```mermaid
graph TD
    A[GitHub Workflow] --> B{Authentication}
    B --> C[OIDC Token]
    C --> D[Azure AD]
    D --> E[Service Principal]
    E --> F[RBAC Check]
    F -->|Authorized| G[Access Logic Apps]
    F -->|Denied| H[Fail]
    
    G --> I[Read Data]
    I --> J[Export to JSON]
    J --> K{Contains Secrets?}
    K -->|Yes| L[Mask/Redact]
    K -->|No| M[Save to Exports]
    L --> M
    M --> N[Generate Docs]
    N --> O[Create PR]
    O --> P[Manual Review]
```

**Security Layers:**
1. **OIDC Authentication**: Passwordless authentication to Azure
2. **RBAC**: Least privilege (Reader role)
3. **Secrets Management**: GitHub Secrets for credentials
4. **Gitignore**: Prevent committing sensitive exports
5. **PR Review**: Human review before merging
6. **Branch Protection**: Require approvals

## 🎯 Execution Flow

### Scheduled Execution

```mermaid
stateDiagram-v2
    [*] --> Scheduled: Cron Trigger (Monday 6 AM)
    Scheduled --> Authenticate: Start Workflow
    Authenticate --> Export: Login Success
    Export --> Generate: Export Complete
    Generate --> Evaluate: Docs Generated
    Evaluate --> CreatePR: Changes Detected
    Evaluate --> Skip: No Changes
    CreatePR --> [*]: Await Review
    Skip --> [*]: Done
```

### Manual Execution

```mermaid
stateDiagram-v2
    [*] --> Manual: User Trigger
    Manual --> InputParams: Optional Parameters
    InputParams --> Authenticate: Start Workflow
    Authenticate --> Export: Login Success
    Export --> Generate: Export Complete
    Generate --> CreatePR: Always Create PR
    CreatePR --> [*]: Await Review
```

## 📈 Scalability Considerations

### Current Design
- Handles **any number** of Logic Apps
- Processes **one subscription** at a time
- Supports **resource group filtering**

### Performance Optimization
1. **Parallel Processing**: Could be added for multiple resource groups
2. **Incremental Updates**: Only process changed Logic Apps
3. **Caching**: Cache Azure API responses
4. **Batching**: Process in batches if many Logic Apps exist

### Limitations
- GitHub Actions 6-hour execution limit
- Azure API rate limits
- Large workflows may generate large documentation

## 🔧 Extension Points

### Adding New Features

1. **Email Notifications**
   - Add email action in workflow
   - Send summary on completion

2. **Slack Integration**
   - Post updates to Slack channel
   - Include links to PRs

3. **Custom Metrics**
   - Add cost analysis
   - Include execution duration trends
   - Analyze failure patterns

4. **Multi-Tenant Support**
   - Loop through multiple subscriptions
   - Aggregate documentation
   - Compare across environments

5. **Change Tracking**
   - Git diff analysis
   - Highlight changes in PRs
   - Version comparison

## 🔄 Maintenance & Operations

### Regular Maintenance
- Review and approve PRs weekly
- Monitor workflow execution logs
- Check for failed runs
- Update service principal credentials (rotate)
- Review and archive old documentation

### Monitoring
- GitHub Actions execution history
- PR creation success rate
- Documentation coverage (% of Logic Apps documented)
- Export/generation duration trends

### Troubleshooting Workflow
```mermaid
graph TD
    A[Issue Detected] --> B{Where?}
    B -->|Export| C[Check Azure Auth]
    B -->|Generate| D[Check JSON Files]
    B -->|Workflow| E[Check GH Actions]
    
    C --> F[Review Logs]
    D --> F
    E --> F
    
    F --> G{Fixed?}
    G -->|Yes| H[Verify]
    G -->|No| I[Escalate]
    H --> J[Document]
```

## 📚 Related Documentation

- [Setup Guide](./SETUP_GUIDE.md) - Installation and configuration
- [Quick Reference](./QUICK_REFERENCE.md) - Common commands
- [Main README](../README.md) - Project overview

---

*Architecture Documentation - Version 1.0*  
*Last Updated: 2025-10-22*
