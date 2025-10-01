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

```bash
pip install -e .
```

Or install dependencies directly:

```bash
pip install -r requirements.txt
```

## Usage

### Command Line Interface

Deploy a .bim file to an SSAS server:

```bash
# Basic deployment
pyssas-deploy deploy model.bim myserver.database.windows.net MyDatabase

# With authentication
pyssas-deploy deploy model.bim myserver MyDatabase -u admin -p password

# Deploy to Azure Analysis Services with HTTPS
pyssas-deploy deploy model.bim asazure://region.asazure.windows.net/myserver MyDatabase --https

# Custom port
pyssas-deploy deploy model.bim myserver MyDatabase --port 2383

# Prevent overwriting existing database
pyssas-deploy deploy model.bim myserver MyDatabase --no-overwrite

# Verbose output
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

## Requirements

- Python 3.7+
- requests library

## How It Works

1. **Load .bim file**: Parses the JSON-based .bim file containing the tabular model definition
2. **Create TMSL script**: Generates a TMSL (Tabular Model Scripting Language) script for deployment
3. **Execute deployment**: Sends the TMSL script to the SSAS server via XMLA (XML for Analysis) endpoint
4. **Return results**: Provides deployment status and details

## Supported Scenarios

- SQL Server Analysis Services (on-premises)
- Azure Analysis Services
- Power BI Premium (via XMLA endpoints)

## Error Handling

The tool includes comprehensive error handling for:
- Invalid or missing .bim files
- Connection failures
- Authentication errors
- Deployment failures

## Development

### Running Tests

```bash
python -m pytest tests/
```

### Building the Package

```bash
python setup.py sdist bdist_wheel
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
