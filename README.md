# pyssas-deploy

Platform-agnostic Python tool for deploying .bim files to SQL Server Analysis Services (SSAS) servers.

## Features

- 🚀 Deploy .bim (Business Intelligence Model) files to SSAS servers
- 🔄 Platform-agnostic (works on Windows, Linux, macOS)
- 🔐 Supports authentication (username/password)
- 🌐 Works with both HTTP and HTTPS endpoints
- 📝 Uses TMSL (Tabular Model Scripting Language) for deployments
- 🔧 Simple CLI and Python API

## Installation

This project uses [UV](https://docs.astral.sh/uv/) for Python package management.

```bash
# Initialize the project (creates venv and installs dependencies)
uv sync

# Activate the virtual environment
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

## Requirements

- Python 3.10 or higher (tested with Python 3.10, 3.11, 3.12, and 3.13)
- UV package manager

## Usage

### Command Line Interface

Deploy a .bim file to an SSAS server:

```bash
# On-premises SSAS 2017-2022 deployment
pyssas-deploy deploy model.bim sqlserver.contoso.com MyDatabase -u domain\\username -p password

# On-premises SSAS with custom instance
pyssas-deploy deploy model.bim sqlserver.contoso.com\\TABULAR MyDatabase -u admin -p password

# Azure Analysis Services with HTTPS
pyssas-deploy deploy model.bim asazure://region.asazure.windows.net/myserver MyDatabase --https

# Custom port for on-premises SSAS
pyssas-deploy deploy model.bim myserver MyDatabase --port 2383

# Prevent overwriting existing database
pyssas-deploy deploy model.bim myserver MyDatabase --no-overwrite

# Verbose output for debugging
pyssas-deploy deploy model.bim myserver MyDatabase -v
```

### Python API

```python
from pyssas_deploy import deploy_bim

# Deploy a .bim file
result = deploy_bim(
    bim_path="path/to/model.bim",
    server="myserver.database.windows.net",
    database_name="MyDatabase",
    username="admin",
    password="password",
    port=2383,
    use_https=True,
    overwrite=True
)

print(f"Deployed to {result['database']} on {result['server']}")
```

## How It Works

1. **Load .bim file**: Parses the JSON-based .bim file containing the tabular model definition
2. **Create TMSL script**: Generates a TMSL (Tabular Model Scripting Language) script for deployment
3. **Execute deployment**: Sends the TMSL script to the SSAS server via XMLA (XML for Analysis) endpoint
4. **Return results**: Provides deployment status and details

## Supported Scenarios

### On-Premises SQL Server Analysis Services
- **SSAS 2017** (Compatibility Level 1400+)
- **SSAS 2019** (Compatibility Level 1400+)
- **SSAS 2022** (Compatibility Level 1400+)

### Cloud Services
- **Azure Analysis Services** (All tiers)
- **Power BI Premium** (via XMLA endpoints)

### Notes on SSAS Compatibility
- This tool uses TMSL (Tabular Model Scripting Language) which was introduced in SQL Server 2016 for Tabular models at compatibility level 1200 or higher
- For SSAS 2017-2022 on-premises deployments:
  - Ensure your tabular model uses compatibility level 1400 or higher
  - XMLA endpoint must be accessible (default port 2383 for HTTP)
  - Windows Authentication or SQL Authentication can be used
  - For secure connections, use HTTPS with appropriate certificates

## Configuring IIS for SSAS HTTP Access (Windows Only)

For on-premises SSAS deployments on Windows, you can use the included PowerShell script to automatically configure IIS for HTTP access to SSAS:

```powershell
# Run as Administrator
.\scripts\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost"

# With custom instance
.\scripts\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost\TABULAR" -IISPort 8080

# With HTTPS
.\scripts\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost" -UseHTTPS -CertificateThumbprint "YOUR_CERT_THUMBPRINT"
```

This script will:
- Install IIS and required features
- Configure MSMDPUMP.DLL for SSAS access
- Create application pool and virtual directory
- Set up Windows Authentication
- Optionally configure HTTPS

For more details, see [Microsoft's documentation](https://learn.microsoft.com/en-us/analysis-services/instances/configure-http-access-to-analysis-services-on-iis-8-0).

## Error Handling

The tool includes comprehensive error handling for:
- Invalid or missing .bim files
- Connection failures
- Authentication errors
- Deployment failures

## Development

### Setting Up Development Environment

```bash
# Initialize the project with UV
uv sync

# Activate the virtual environment
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### Running Tests

```bash
python -m unittest discover -s tests -v
```

### Building the Package

```bash
uv build
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
