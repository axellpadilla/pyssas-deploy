# SSAS HTTP Access Configuration Scripts

This directory contains scripts to help configure IIS for HTTP access to SQL Server Analysis Services (SSAS).

## Configure-SSASHttpAccess.ps1

PowerShell script that automates the installation and configuration of IIS on Windows to enable HTTP access to SSAS Tabular instances.

### Prerequisites

- Windows Server 2012 R2, 2016, 2019, or 2022
- Administrator privileges
- SQL Server Analysis Services (SSAS) installed
- PowerShell 5.1 or higher

### Usage

**Basic Configuration:**
```powershell
.\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost"
```

**Named Instance:**
```powershell
.\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost\TABULAR"
```

**Custom Port:**
```powershell
.\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost" -IISPort 8080
```

**With HTTPS:**
```powershell
.\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost" -UseHTTPS -CertificateThumbprint "YOUR_CERT_THUMBPRINT"
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `SSASServerName` | Yes | - | SSAS server name or instance (e.g., "localhost" or "localhost\TABULAR") |
| `SSASPort` | No | 2383 | SSAS MSOLAP port |
| `IISPort` | No | 80 | IIS port to listen on (use 443 for HTTPS) |
| `UseHTTPS` | No | false | Enable HTTPS/SSL configuration |
| `CertificateThumbprint` | No | - | Certificate thumbprint for HTTPS (required if UseHTTPS is enabled) |

### What It Does

1. **Installs IIS** with required features (ISAPI extensions, filters, etc.)
2. **Locates MSMDPUMP.DLL** from SSAS installation
3. **Creates Application Pool** named "SSASPool" for SSAS requests
4. **Creates Virtual Directory** at `/OLAP` with MSMDPUMP files
5. **Configures MSMDPUMP.INI** with connection settings
6. **Sets up ISAPI Handler** mappings for MSMDPUMP.DLL
7. **Enables Windows Authentication** and disables anonymous access
8. **Optional HTTPS** configuration with certificate binding

### Testing the Configuration

After running the script, test the endpoint:

```bash
# Using curl
curl -u "domain\username:password" http://localhost/OLAP/msmdpump.dll

# Using pyssas-deploy
pyssas-deploy deploy model.bim localhost/OLAP MyDatabase -u domain\username -p password
```

### Troubleshooting

**Check MSMDPUMP Log:**
```
C:\inetpub\wwwroot\OLAP\msmdpump.log
```

**Verify IIS Configuration:**
```powershell
Get-WebApplication
Get-WebBinding
```

**Test SSAS Connection:**
```powershell
# Ensure SSAS service is running
Get-Service MSOLAP*

# Check SSAS port is listening
netstat -ano | findstr 2383
```

**Common Issues:**

1. **404 Error**: Virtual directory not created properly
   - Check IIS configuration
   - Verify MSMDPUMP files copied correctly

2. **401 Error**: Authentication issue
   - Verify Windows Authentication is enabled
   - Check user has SSAS permissions
   - Ensure proper domain\username format

3. **500 Error**: MSMDPUMP.DLL configuration issue
   - Check MSMDPUMP.INI settings
   - Verify SSAS server name is correct
   - Review msmdpump.log for details

### Security Considerations

- The script configures Windows Authentication by default
- Anonymous access is disabled for security
- For production environments, consider:
  - Using HTTPS with valid SSL certificates
  - Restricting IIS access to specific IP addresses
  - Implementing additional authentication layers
  - Regular security audits and updates

### References

- [Configure HTTP Access to Analysis Services on IIS 8.0](https://learn.microsoft.com/en-us/analysis-services/instances/configure-http-access-to-analysis-services-on-iis-8-0)
- [MSMDPUMP.DLL Configuration](https://learn.microsoft.com/en-us/analysis-services/instances/install-windows/configure-http-access-to-analysis-services-on-iis-7-0)
- [SSAS Tabular Model Deployment](https://learn.microsoft.com/en-us/analysis-services/deployment/deployment-and-operations)

## Support

For issues related to:
- **Script functionality**: Open an issue in the repository
- **SSAS configuration**: Refer to Microsoft documentation
- **IIS configuration**: Consult Windows Server documentation
