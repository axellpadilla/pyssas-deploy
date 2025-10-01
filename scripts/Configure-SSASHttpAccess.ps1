<#
.SYNOPSIS
    Configures IIS to provide HTTP access to SQL Server Analysis Services (SSAS).

.DESCRIPTION
    This script automates the installation and configuration of IIS on Windows to enable
    HTTP access to SSAS Tabular instances. It implements the steps documented at:
    https://learn.microsoft.com/en-us/analysis-services/instances/configure-http-access-to-analysis-services-on-iis-8-0

.PARAMETER SSASServerName
    The SSAS server name or instance (e.g., "localhost" or "localhost\TABULAR")

.PARAMETER SSASPort
    The SSAS MSOLAP port (default: 2383)

.PARAMETER IISPort
    The IIS port to listen on (default: 80, use 443 for HTTPS)

.PARAMETER UseHTTPS
    Enable HTTPS/SSL configuration (requires certificate)

.PARAMETER CertificateThumbprint
    Certificate thumbprint for HTTPS (required if UseHTTPS is enabled)

.EXAMPLE
    .\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost"

.EXAMPLE
    .\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost\TABULAR" -SSASPort 2383 -IISPort 8080

.EXAMPLE
    .\Configure-SSASHttpAccess.ps1 -SSASServerName "localhost" -UseHTTPS -CertificateThumbprint "THUMBPRINT"

.NOTES
    Requires Administrator privileges
    Compatible with Windows Server 2012 R2, 2016, 2019, 2022
    Tested with SSAS 2017, 2019, 2022
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SSASServerName,
    
    [Parameter(Mandatory=$false)]
    [int]$SSASPort = 2383,
    
    [Parameter(Mandatory=$false)]
    [int]$IISPort = 80,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseHTTPS,
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateThumbprint
)

# Ensure script is run as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell with elevated privileges."
    exit 1
}

Write-Host "=== SSAS HTTP Access Configuration Script ===" -ForegroundColor Cyan
Write-Host "SSAS Server: $SSASServerName" -ForegroundColor Yellow
Write-Host "SSAS Port: $SSASPort" -ForegroundColor Yellow
Write-Host "IIS Port: $IISPort" -ForegroundColor Yellow
Write-Host "Use HTTPS: $UseHTTPS" -ForegroundColor Yellow
Write-Host ""

# Step 1: Install IIS and required features
Write-Host "[1/7] Installing IIS and required features..." -ForegroundColor Green
try {
    $iisFeatures = @(
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Http-Logging",
        "Web-Stat-Compression",
        "Web-Filtering",
        "Web-ISAPI-Ext",
        "Web-ISAPI-Filter",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console"
    )
    
    foreach ($feature in $iisFeatures) {
        $installed = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
        if ($installed -and $installed.Installed -eq $false) {
            Write-Host "  Installing $feature..." -ForegroundColor Gray
            Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop | Out-Null
        } else {
            Write-Host "  $feature already installed" -ForegroundColor Gray
        }
    }
    Write-Host "  IIS installation complete!" -ForegroundColor Green
} catch {
    Write-Error "Failed to install IIS: $_"
    exit 1
}

# Step 2: Install MSMDPUMP.dll prerequisites
Write-Host "[2/7] Checking MSMDPUMP.dll prerequisites..." -ForegroundColor Green
$msmdpumpPath = "${env:ProgramFiles}\Microsoft SQL Server\MSAS*\OLAP\bin\isapi\MSMDPUMP.DLL"
$msmdpumpFound = Get-Item $msmdpumpPath -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $msmdpumpFound) {
    Write-Warning "MSMDPUMP.DLL not found. Please ensure SSAS is installed."
    Write-Warning "Expected location: $msmdpumpPath"
    Write-Host "Continuing with configuration..." -ForegroundColor Yellow
} else {
    Write-Host "  Found MSMDPUMP.DLL at: $($msmdpumpFound.FullName)" -ForegroundColor Gray
}

# Step 3: Create Application Pool
Write-Host "[3/7] Creating IIS Application Pool..." -ForegroundColor Green
try {
    Import-Module WebAdministration -ErrorAction Stop
    
    $appPoolName = "SSASPool"
    $appPool = Get-Item "IIS:\AppPools\$appPoolName" -ErrorAction SilentlyContinue
    
    if ($appPool) {
        Write-Host "  Application pool '$appPoolName' already exists" -ForegroundColor Gray
        Remove-Item "IIS:\AppPools\$appPoolName" -Recurse -Force
        Write-Host "  Removed existing application pool" -ForegroundColor Gray
    }
    
    New-Item "IIS:\AppPools\$appPoolName" -Force | Out-Null
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "enable32BitAppOnWin64" -Value $false
    
    Write-Host "  Application pool '$appPoolName' created successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to create application pool: $_"
    exit 1
}

# Step 4: Create Virtual Directory
Write-Host "[4/7] Creating virtual directory..." -ForegroundColor Green
try {
    $vdirName = "OLAP"
    $vdirPath = "IIS:\Sites\Default Web Site\$vdirName"
    
    if (Test-Path $vdirPath) {
        Write-Host "  Virtual directory '$vdirName' already exists" -ForegroundColor Gray
        Remove-Item $vdirPath -Recurse -Force
        Write-Host "  Removed existing virtual directory" -ForegroundColor Gray
    }
    
    # Create physical directory
    $physicalPath = "${env:SystemDrive}\inetpub\wwwroot\$vdirName"
    if (-not (Test-Path $physicalPath)) {
        New-Item -Path $physicalPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy MSMDPUMP files
    if ($msmdpumpFound) {
        $msmdpumpDir = Split-Path $msmdpumpFound.FullName
        Copy-Item "$msmdpumpDir\*" -Destination $physicalPath -Recurse -Force
        Write-Host "  Copied MSMDPUMP files to $physicalPath" -ForegroundColor Gray
    }
    
    # Create virtual directory
    New-Item $vdirPath -Type VirtualDirectory -PhysicalPath $physicalPath -Force | Out-Null
    Set-ItemProperty $vdirPath -Name "applicationPool" -Value $appPoolName
    
    Write-Host "  Virtual directory created at: http://localhost/$vdirName" -ForegroundColor Green
} catch {
    Write-Error "Failed to create virtual directory: $_"
    exit 1
}

# Step 5: Configure MSMDPUMP.INI
Write-Host "[5/7] Configuring MSMDPUMP.INI..." -ForegroundColor Green
try {
    $iniPath = "$physicalPath\MSMDPUMP.INI"
    
    $iniContent = @"
[MSOLAP]
ServerName=$SSASServerName
ConnectionPoolSize=20
MaxConnectionPoolSize=40
ConnectionIdleTimeout=300000

[MSMDPUMP]
AllowAnonymous=0
LogFile=$physicalPath\msmdpump.log
LogLevel=1
RequestTimeout=300000
"@
    
    Set-Content -Path $iniPath -Value $iniContent -Force
    Write-Host "  MSMDPUMP.INI configured for server: $SSASServerName" -ForegroundColor Green
} catch {
    Write-Error "Failed to configure MSMDPUMP.INI: $_"
    exit 1
}

# Step 6: Configure Handler Mappings
Write-Host "[6/7] Configuring ISAPI handler mappings..." -ForegroundColor Green
try {
    # Enable ISAPI-dll handler if not already enabled
    $config = Get-WebConfiguration -Filter "system.webServer/handlers" -PSPath "IIS:\Sites\Default Web Site\$vdirName"
    
    # Add MSMDPUMP.DLL handler
    if ($msmdpumpFound) {
        $handlerName = "MSMDPUMP"
        Remove-WebHandler -Name $handlerName -PSPath "IIS:\Sites\Default Web Site\$vdirName" -ErrorAction SilentlyContinue
        
        New-WebHandler -Name $handlerName `
            -Path "*.dll" `
            -Verb "*" `
            -Modules "IsapiModule" `
            -ScriptProcessor $msmdpumpFound.FullName `
            -ResourceType "Unspecified" `
            -RequireAccess "Execute" `
            -PSPath "IIS:\Sites\Default Web Site\$vdirName" `
            -ErrorAction Stop
        
        Write-Host "  ISAPI handler configured successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to configure handler mappings: $_"
    exit 1
}

# Step 7: Configure Authentication
Write-Host "[7/7] Configuring authentication..." -ForegroundColor Green
try {
    # Disable anonymous authentication
    Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" `
        -Name "enabled" -Value "False" -PSPath "IIS:\Sites\Default Web Site\$vdirName"
    
    # Enable Windows authentication
    Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" `
        -Name "enabled" -Value "True" -PSPath "IIS:\Sites\Default Web Site\$vdirName"
    
    Write-Host "  Authentication configured (Windows Authentication enabled)" -ForegroundColor Green
} catch {
    Write-Error "Failed to configure authentication: $_"
    exit 1
}

# Configure HTTPS if requested
if ($UseHTTPS) {
    Write-Host "[Bonus] Configuring HTTPS..." -ForegroundColor Green
    
    if (-not $CertificateThumbprint) {
        Write-Warning "Certificate thumbprint not provided. Skipping HTTPS configuration."
    } else {
        try {
            # Verify certificate exists (will throw error if not found)
            Get-ChildItem -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction Stop | Out-Null
            
            # Create HTTPS binding
            $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -Port $IISPort -ErrorAction SilentlyContinue
            if (-not $binding) {
                New-WebBinding -Name "Default Web Site" -Protocol "https" -Port $IISPort -SslFlags 0
                
                # Associate certificate
                $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -Port $IISPort
                $binding.AddSslCertificate($CertificateThumbprint, "my")
                
                Write-Host "  HTTPS configured on port $IISPort" -ForegroundColor Green
            } else {
                Write-Host "  HTTPS binding already exists on port $IISPort" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to configure HTTPS: $_"
        }
    }
}

# Summary
Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "SSAS HTTP Access Endpoint:" -ForegroundColor Yellow
if ($UseHTTPS -and $CertificateThumbprint) {
    Write-Host "  https://localhost:$IISPort/OLAP/msmdpump.dll" -ForegroundColor White
} else {
    Write-Host "  http://localhost:$IISPort/OLAP/msmdpump.dll" -ForegroundColor White
}
Write-Host ""
Write-Host "Test the endpoint with pyssas-deploy:" -ForegroundColor Yellow
Write-Host "  pyssas-deploy deploy model.bim localhost/$vdirName MyDatabase -u domain\user -p password --port $IISPort" -ForegroundColor White
Write-Host ""
Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "  1. Ensure SSAS service is running" -ForegroundColor Gray
Write-Host "  2. Configure firewall rules if accessing remotely" -ForegroundColor Gray
Write-Host "  3. Verify Windows Authentication permissions" -ForegroundColor Gray
Write-Host "  4. Check MSMDPUMP.log for troubleshooting: $physicalPath\msmdpump.log" -ForegroundColor Gray
Write-Host ""
Write-Host "For more information, visit:" -ForegroundColor Yellow
Write-Host "  https://learn.microsoft.com/en-us/analysis-services/instances/configure-http-access-to-analysis-services-on-iis-8-0" -ForegroundColor White
Write-Host ""
