# Main Service Deployment Orchestrator
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$false)]
    [string]$CACommonName = "WS2025Lab-RootCA",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\Service-Deployment.log",

    [Parameter(Mandatory=$false)]
    [switch]$SkipADCS,

    [Parameter(Mandatory=$false)]
    [switch]$SkipLegacyApp
)

# Initialize logging
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Ensure Scripts directory exists
$scriptsRoot = "C:\Scripts"
if (-not (Test-Path $scriptsRoot)) {
    New-Item -ItemType Directory -Path $scriptsRoot -Force | Out-Null
}

# Ensure Logs directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logMessage
    
    switch ($Level) {
        'Info' { Write-Host $logMessage }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error' { Write-Host $logMessage -ForegroundColor Red }
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Script must run with administrative privileges" -Level Error
        return $false
    }
    
    # Check domain membership
    try {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        if ($domain.Name -ne $DomainName) {
            Write-Log "Computer is not joined to the correct domain ($DomainName)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Computer is not joined to a domain" -Level Error
        return $false
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.0 or higher is required" -Level Error
        return $false
    }
    
    Write-Log "All prerequisites met"
    return $true
}

function Deploy-ADCS {
    Write-Log "Starting ADCS deployment..."
    
    $adcsScript = Join-Path $PSScriptRoot "setup-adcs.ps1"
    if (-not (Test-Path $adcsScript)) {
        Write-Log "ADCS setup script not found at: $adcsScript" -Level Error
        return $false
    }
    
    try {
        & $adcsScript -DomainName $DomainName -CACommonName $CACommonName
        if ($LASTEXITCODE -ne 0) {
            Write-Log "ADCS setup failed with exit code: $LASTEXITCODE" -Level Error
            return $false
        }
        Write-Log "ADCS deployment completed successfully"
        return $true
    }
    catch {
        Write-Log "Error during ADCS deployment: $_" -Level Error
        return $false
    }
}

function Deploy-LegacyApp {
    Write-Log "Starting Legacy App deployment..."
    
    $legacyAppScript = Join-Path $PSScriptRoot "setup-legacy-app.ps1"
    if (-not (Test-Path $legacyAppScript)) {
        Write-Log "Legacy App setup script not found at: $legacyAppScript" -Level Error
        return $false
    }
    
    try {
        & $legacyAppScript -DomainName $DomainName
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Legacy App setup failed with exit code: $LASTEXITCODE" -Level Error
            return $false
        }
        Write-Log "Legacy App deployment completed successfully"
        return $true
    }
    catch {
        Write-Log "Error during Legacy App deployment: $_" -Level Error
        return $false
    }
}

function Configure-Certificates {
    Write-Log "Configuring certificates for deployed services..."
    
    $certScript = "C:\Scripts\Configure-Certificates.ps1"
    if (-not (Test-Path $certScript)) {
        Write-Log "Certificate configuration script not found at: $certScript" -Level Warning
        return $false
    }
    
    try {
        & $certScript
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Certificate configuration failed with exit code: $LASTEXITCODE" -Level Error
            return $false
        }
        Write-Log "Certificate configuration completed successfully"
        return $true
    }
    catch {
        Write-Log "Error during certificate configuration: $_" -Level Error
        return $false
    }
}

# Main execution flow
Write-Log "Starting service deployment for domain: $DomainName"

if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Exiting." -Level Error
    exit 1
}

$deploymentSuccess = $true

if (-not $SkipADCS) {
    if (-not (Deploy-ADCS)) {
        $deploymentSuccess = $false
        Write-Log "ADCS deployment failed" -Level Error
    }
}

if (-not $SkipLegacyApp) {
    if (-not (Deploy-LegacyApp)) {
        $deploymentSuccess = $false
        Write-Log "Legacy App deployment failed" -Level Error
    }
}

if ($deploymentSuccess) {
    Write-Log "Waiting for certificate services to be ready..."
    Start-Sleep -Seconds 60
    
    if (-not (Configure-Certificates)) {
        Write-Log "Certificate configuration failed" -Level Warning
    }
    
    Write-Log "Service deployment completed successfully"
    Write-Log @"
Deployment Summary:
------------------
Domain: $DomainName
CA Name: $CACommonName
ADCS Status: $(if(-not $SkipADCS) { "Deployed" } else { "Skipped" })
Legacy App Status: $(if(-not $SkipLegacyApp) { "Deployed" } else { "Skipped" })

Next Steps:
1. Verify ADCS is operational: certutil -ping
2. Check Legacy App: https://$(hostname).$DomainName/LegacyApp
3. Review logs at: $LogPath
"@
} else {
    Write-Log "Service deployment completed with errors. Please review the logs." -Level Error
    exit 1
} 