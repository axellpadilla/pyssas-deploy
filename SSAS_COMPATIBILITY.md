# SSAS Version Compatibility Guide

## Supported SSAS Versions

This tool has been designed and tested to work with the following SQL Server Analysis Services versions:

### On-Premises SSAS Versions

| Version | Support Status | Minimum Compatibility Level | Notes |
|---------|---------------|----------------------------|-------|
| SSAS 2017 | ✅ Fully Supported | 1400 | Requires TMSL and XMLA endpoint access |
| SSAS 2019 | ✅ Fully Supported | 1400 | Full TMSL support, recommended |
| SSAS 2022 | ✅ Fully Supported | 1400 | Latest version, full feature support |

### Cloud SSAS Services

| Service | Support Status | Notes |
|---------|---------------|-------|
| Azure Analysis Services | ✅ Fully Supported | All tiers supported |
| Power BI Premium | ✅ Fully Supported | Via XMLA endpoints |

## Technical Requirements

### For On-Premises SSAS 2017-2022

1. **TMSL Support**: 
   - Tabular Model Scripting Language (TMSL) must be supported
   - Available in SQL Server 2016+ for tabular models
   - Compatibility level 1200 or higher required (1400+ recommended)

2. **XMLA Endpoint Access**:
   - Default port: 2383 (HTTP)
   - Must be accessible from deployment machine
   - Firewall rules may need configuration

3. **Authentication**:
   - Windows Authentication (domain accounts)
   - SQL Server Authentication
   - Format for Windows auth: `domain\username`

4. **Model Requirements**:
   - Tabular model (not multidimensional)
   - Compatibility level 1400 or higher recommended
   - .bim file must be in JSON format

## Deployment Examples by Version

### SSAS 2017

```bash
# Basic deployment to SSAS 2017 with Windows Authentication
pyssas-deploy deploy model.bim sqlserver2017.contoso.com MyDatabase -u contoso\\username -p password

# SSAS 2017 with named instance
pyssas-deploy deploy model.bim sqlserver2017\\TABULAR MyDatabase -u contoso\\username -p password
```

### SSAS 2019

```bash
# SSAS 2019 deployment with SQL Authentication
pyssas-deploy deploy model.bim sqlserver2019.contoso.com MyDatabase -u sa -p password

# SSAS 2019 with HTTPS (if configured)
pyssas-deploy deploy model.bim sqlserver2019.contoso.com MyDatabase -u sa -p password --https
```

### SSAS 2022

```bash
# SSAS 2022 deployment (same as previous versions)
pyssas-deploy deploy model.bim sqlserver2022.contoso.com MyDatabase -u admin -p password

# SSAS 2022 with custom port
pyssas-deploy deploy model.bim sqlserver2022.contoso.com MyDatabase -u admin -p password --port 2383
```

## Known Limitations

### SSAS 2016 and Earlier
- **Not supported**: SSAS 2016 and earlier versions use different deployment mechanisms
- **Reason**: While TMSL was introduced in SQL Server 2016, the XMLA HTTP endpoint implementation may vary
- **Alternative**: Use Microsoft's official deployment tools (Microsoft.AnalysisServices.Deployment.exe)

### Multidimensional Models
- **Not supported**: Only tabular models are supported
- **Reason**: This tool uses TMSL which is specific to tabular models
- **Alternative**: Use XMLA scripts or AMO for multidimensional model deployment

## Compatibility Level Reference

| Compatibility Level | SQL Server Version | Release Year | Support Status |
|--------------------|-------------------|--------------|----------------|
| 1200 | SQL Server 2016 | 2016 | ⚠️ Limited |
| 1400 | SQL Server 2017 | 2017 | ✅ Supported |
| 1450 | SQL Server 2019 | 2018 | ✅ Supported |
| 1500 | SQL Server 2019 | 2019 | ✅ Supported |
| 1520 | SQL Server 2022 | 2021 | ✅ Supported |
| 1550 | SQL Server 2022 | 2022 | ✅ Supported |

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to SSAS server
- Verify XMLA endpoint is accessible (port 2383)
- Check firewall rules
- Ensure SSAS service is running
- Verify network connectivity

**Problem**: Authentication failures
- For Windows Auth, use format: `domain\username`
- Ensure user has appropriate SSAS permissions
- Check credentials are correct

### Deployment Failures

**Problem**: "Compatibility level not supported"
- Ensure your model uses compatibility level 1400+
- Update model compatibility level in your development tool

**Problem**: "Database already exists" error
- Use `--no-overwrite` flag to prevent overwriting
- Or ensure overwrite is intentional (default behavior)

## Testing Compatibility

To verify your SSAS instance is compatible:

1. Check SSAS version:
   ```sql
   SELECT SERVERPROPERTY('ProductVersion') AS Version,
          SERVERPROPERTY('Edition') AS Edition
   ```

2. Verify XMLA endpoint:
   ```bash
   curl http://your-ssas-server:2383/xmla
   ```

3. Test deployment with a simple model:
   ```bash
   pyssas-deploy deploy examples/sample_model.bim your-server TestDB -u user -p pass -v
   ```

## Additional Resources

- [Microsoft TMSL Documentation](https://docs.microsoft.com/en-us/analysis-services/tmsl/tabular-model-scripting-language-tmsl-reference)
- [SSAS Tabular Model Compatibility Levels](https://docs.microsoft.com/en-us/analysis-services/tabular-models/compatibility-level-for-tabular-models-in-analysis-services)
- [XMLA Endpoints](https://docs.microsoft.com/en-us/analysis-services/xmla/xml-for-analysis-xmla-reference)

## Support Matrix

| Feature | SSAS 2017 | SSAS 2019 | SSAS 2022 | Azure AS | Power BI Premium |
|---------|-----------|-----------|-----------|----------|------------------|
| HTTP Deployment | ✅ | ✅ | ✅ | ✅ | ✅ |
| HTTPS Deployment | ✅ | ✅ | ✅ | ✅ | ✅ |
| Windows Auth | ✅ | ✅ | ✅ | ❌ | ❌ |
| SQL Auth | ✅ | ✅ | ✅ | ❌ | ❌ |
| AAD Auth | ❌ | ❌ | ❌ | ✅ | ✅ |
| Named Instances | ✅ | ✅ | ✅ | N/A | N/A |
| Custom Ports | ✅ | ✅ | ✅ | ✅ | ✅ |

Note: AAD (Azure Active Directory) authentication support is planned for future releases.
