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
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "=== SSAS HTTP Access Configuration Script ===" -ForegroundColor Cyan
Write-Host "SSAS Server: $SSASServerName" -ForegroundColor Yellow
Write-Host "SSAS Port: $SSASPort" -ForegroundColor Yellow
Write-Host "IIS Port: $IISPort" -ForegroundColor Yellow
Write-Host "Use HTTPS: $UseHTTPS" -ForegroundColor Yellow
Write-Host ""

# Pre-flight checks
Write-Host "[Pre-flight] Running validation checks..." -ForegroundColor Green

# Check 1: Verify SSAS service is running
Write-Host "  Checking SSAS service status..." -ForegroundColor Gray
$ssasServices = Get-Service -Name "MSOLAP*" -ErrorAction SilentlyContinue
if ($ssasServices) {
    $runningServices = $ssasServices | Where-Object { $_.Status -eq "Running" }
    if ($runningServices) {
        foreach ($service in $runningServices) {
            Write-Host "  [OK] SSAS service '$($service.DisplayName)' is running" -ForegroundColor Green
        }
    } else {
        Write-Warning "SSAS service(s) found but not running:"
        foreach ($service in $ssasServices) {
            Write-Warning "  - $($service.DisplayName): $($service.Status)"
        }
        $continue = Read-Host "Do you want to continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Configuration cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
} else {
    Write-Warning "No SSAS services found on this machine."
    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Configuration cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

# Check 2: Verify SSAS port availability
Write-Host "  Checking SSAS port $SSASPort..." -ForegroundColor Gray
$ssasPortInUse = Get-NetTCPConnection -LocalPort $SSASPort -State Listen -ErrorAction SilentlyContinue
if ($ssasPortInUse) {
    $processId = $ssasPortInUse[0].OwningProcess
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    Write-Host "  [OK] Port $SSASPort is in use by: $($process.ProcessName) (PID: $processId)" -ForegroundColor Green
} else {
    Write-Warning "Port $SSASPort is not in use. SSAS may not be listening on this port."
    Write-Warning "  Common SSAS ports: 2383 (default), 2382, or dynamic port"
    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Configuration cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

# Check 3: Verify IIS port availability
Write-Host "  Checking IIS port $IISPort..." -ForegroundColor Gray
$iisPortInUse = Get-NetTCPConnection -LocalPort $IISPort -State Listen -ErrorAction SilentlyContinue
if ($iisPortInUse) {
    $processId = $iisPortInUse[0].OwningProcess
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    Write-Warning "Port $IISPort is already in use by: $($process.ProcessName) (PID: $processId)"
    
    # Check if it's IIS
    if ($process.ProcessName -like "*w3wp*" -or $process.ProcessName -eq "inetinfo") {
        Write-Host "  [INFO] Port is used by IIS - configuration will update existing binding" -ForegroundColor Cyan
    } else {
        Write-Warning "  Port is used by a non-IIS process. This may cause conflicts."
        $continue = Read-Host "Do you want to continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Configuration cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
} else {
    Write-Host "  [OK] Port $IISPort is available" -ForegroundColor Green
}

Write-Host "  Pre-flight checks complete!" -ForegroundColor Green
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
    
    # Create application (not just virtual directory) to assign app pool
    New-WebApplication -Name $vdirName -Site "Default Web Site" -PhysicalPath $physicalPath -ApplicationPool $appPoolName -Force | Out-Null
    
    Write-Host "  Web application created at: http://localhost/$vdirName" -ForegroundColor Green
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
    # Unlock handlers section to allow configuration at application level
    Write-Host "  Unlocking handlers section..." -ForegroundColor Gray
    & $env:windir\system32\inetsrv\appcmd.exe unlock config -section:system.webServer/handlers
    
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
    # Unlock authentication sections to allow configuration at application level
    Write-Host "  Unlocking authentication sections..." -ForegroundColor Gray
    & $env:windir\system32\inetsrv\appcmd.exe unlock config -section:system.webServer/security/authentication/anonymousAuthentication
    & $env:windir\system32\inetsrv\appcmd.exe unlock config -section:system.webServer/security/authentication/windowsAuthentication
    
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

# Post-validation checks
Write-Host ""
Write-Host "[Post-validation] Verifying configuration..." -ForegroundColor Green

# Check 1: Verify Application Pool is running
Write-Host "  Checking application pool status..." -ForegroundColor Gray
try {
    $appPool = Get-Item "IIS:\AppPools\$appPoolName" -ErrorAction Stop
    $appPoolState = $appPool.State
    
    if ($appPoolState -eq "Started") {
        Write-Host "  [OK] Application pool '$appPoolName' is running" -ForegroundColor Green
    } else {
        Write-Warning "Application pool '$appPoolName' state: $appPoolState"
        Write-Host "  Attempting to start application pool..." -ForegroundColor Gray
        Start-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $appPool = Get-Item "IIS:\AppPools\$appPoolName"
        if ($appPool.State -eq "Started") {
            Write-Host "  [OK] Application pool started successfully" -ForegroundColor Green
        } else {
            Write-Warning "Failed to start application pool. Check Event Viewer for details."
        }
    }
} catch {
    Write-Warning "Could not verify application pool status: $_"
}

# Check 2: Verify Web Application exists
Write-Host "  Checking web application..." -ForegroundColor Gray
try {
    $webApp = Get-WebApplication -Name $vdirName -Site "Default Web Site" -ErrorAction Stop
    if ($webApp) {
        Write-Host "  [OK] Web application '$vdirName' exists" -ForegroundColor Green
        Write-Host "    Physical path: $($webApp.PhysicalPath)" -ForegroundColor Gray
        Write-Host "    Application pool: $($webApp.ApplicationPool)" -ForegroundColor Gray
    }
} catch {
    Write-Warning "Could not verify web application: $_"
}

# Check 3: Verify MSMDPUMP.dll is accessible
Write-Host "  Checking MSMDPUMP.dll..." -ForegroundColor Gray
$msmdpumpDll = Join-Path $physicalPath "MSMDPUMP.dll"
if (Test-Path $msmdpumpDll) {
    Write-Host "  [OK] MSMDPUMP.dll exists at: $msmdpumpDll" -ForegroundColor Green
} else {
    Write-Warning "MSMDPUMP.dll not found at: $msmdpumpDll"
}

# Check 4: Verify MSMDPUMP.INI exists and contains correct server
Write-Host "  Checking MSMDPUMP.INI..." -ForegroundColor Gray
$iniPath = "$physicalPath\MSMDPUMP.INI"
if (Test-Path $iniPath) {
    $iniContent = Get-Content $iniPath -Raw
    if ($iniContent -match "ServerName\s*=\s*$([regex]::Escape($SSASServerName))") {
        Write-Host "  [OK] MSMDPUMP.INI configured for server: $SSASServerName" -ForegroundColor Green
    } else {
        Write-Warning "MSMDPUMP.INI exists but may not be configured correctly"
    }
} else {
    Write-Warning "MSMDPUMP.INI not found at: $iniPath"
}

# Check 5: Verify ISAPI handler is registered
Write-Host "  Checking ISAPI handler mapping..." -ForegroundColor Gray
try {
    $handlers = Get-WebHandler -PSPath "IIS:\Sites\Default Web Site\$vdirName" -ErrorAction Stop
    $msmdpumpHandler = $handlers | Where-Object { $_.Name -eq "MSMDPUMP" }
    if ($msmdpumpHandler) {
        Write-Host "  [OK] MSMDPUMP handler registered" -ForegroundColor Green
        Write-Host "    Path: $($msmdpumpHandler.Path)" -ForegroundColor Gray
        Write-Host "    Script processor: $($msmdpumpHandler.ScriptProcessor)" -ForegroundColor Gray
    } else {
        Write-Warning "MSMDPUMP handler not found in handler mappings"
    }
} catch {
    Write-Warning "Could not verify handler mappings: $_"
}

# Check 6: Verify authentication settings
Write-Host "  Checking authentication settings..." -ForegroundColor Gray
try {
    $anonAuth = Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" `
        -Name "enabled" -PSPath "IIS:\Sites\Default Web Site\$vdirName" -ErrorAction Stop
    $winAuth = Get-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" `
        -Name "enabled" -PSPath "IIS:\Sites\Default Web Site\$vdirName" -ErrorAction Stop
    
    if ($anonAuth.Value -eq $false -and $winAuth.Value -eq $true) {
        Write-Host "  [OK] Authentication configured correctly" -ForegroundColor Green
        Write-Host "    Anonymous: Disabled" -ForegroundColor Gray
        Write-Host "    Windows: Enabled" -ForegroundColor Gray
    } else {
        Write-Warning "Authentication settings may not be correct:"
        Write-Warning "  Anonymous: $($anonAuth.Value) (should be False)"
        Write-Warning "  Windows: $($winAuth.Value) (should be True)"
    }
} catch {
    Write-Warning "Could not verify authentication settings: $_"
}

# Check 7: Test HTTP endpoint accessibility
Write-Host "  Testing HTTP endpoint..." -ForegroundColor Gray
try {
    $protocol = if ($UseHTTPS -and $CertificateThumbprint) { "https" } else { "http" }
    $testUrl = "${protocol}://localhost:$IISPort/$vdirName/msmdpump.dll"
    
    # Simple connectivity test (will return 401 without credentials, which is expected)
    $response = Invoke-WebRequest -Uri $testUrl -Method GET -UseBasicParsing -UseDefaultCredentials -ErrorAction SilentlyContinue
    
    if ($response.StatusCode -eq 200) {
        Write-Host "  [OK] Endpoint is accessible: $testUrl" -ForegroundColor Green
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    if ($statusCode -eq 401) {
        Write-Host "  [OK] Endpoint is accessible (401 Unauthorized - credentials required)" -ForegroundColor Green
    } elseif ($statusCode -eq 403) {
        Write-Host "  [WARN] Endpoint accessible but returns 403 Forbidden" -ForegroundColor Yellow
        Write-Host "    This may be normal - verify permissions are configured" -ForegroundColor Gray
    } else {
        Write-Warning "Could not access endpoint: HTTP $statusCode"
        Write-Warning "  URL tested: $testUrl"
    }
}

Write-Host "  Post-validation complete!" -ForegroundColor Green
Write-Host ""

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
