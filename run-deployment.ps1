# Automated deployment script for Windows Server 2025 Learning Lab
# This script runs the deployment with predefined parameters

# Generate a random password
function Generate-RandomPassword {
    $passwordLength = 16
    $alphabets = "abcdefghijklmnopqrstuvwxyz"
    $upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*()_+-=[]{}|;':,./<>?"
    
    $password = ""
    $password += ($alphabets.ToCharArray() | Get-Random)  # at least one lowercase
    $password += ($upperCase.ToCharArray() | Get-Random)  # at least one uppercase
    $password += ($numbers.ToCharArray() | Get-Random)    # at least one number
    $password += ($special.ToCharArray() | Get-Random)    # at least one special char
    
    # Fill the rest randomly
    $allChars = $alphabets + $upperCase + $numbers + $special
    $remainingLength = $passwordLength - 4
    for ($i = 0; $i -lt $remainingLength; $i++) {
        $password += ($allChars.ToCharArray() | Get-Random)
    }
    
    # Shuffle the password
    $passwordArray = $password.ToCharArray()
    $shuffledArray = $passwordArray | Get-Random -Count $passwordArray.Length
    $password = -join $shuffledArray
    
    return $password
}

# Clean up any existing resource group with the same name (BE CAREFUL WITH THIS!)
$ResourceGroupName = "rg-ws2025-lab"
$existingGroup = az group exists --name $ResourceGroupName
if ($existingGroup -contains "true") {
    Write-Host "Cleaning up existing resource group: $ResourceGroupName" -ForegroundColor Yellow
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "Waiting for resource group deletion to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120  # Wait for deletion to complete
}

# Configuration
$DomainName = "winlab2025"
$Location = "eastus"
$AdminUsername = "labadmin"
$AdminPassword = Generate-RandomPassword

Write-Host "===================================================="
Write-Host "Automated Windows Server 2025 Learning Lab Deployment"
Write-Host "===================================================="
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Domain Name: $DomainName"
Write-Host "Location: $Location"
Write-Host "Admin Username: $AdminUsername"
Write-Host "Admin Password: $AdminPassword"
Write-Host ""
Write-Host "IMPORTANT: Save this password in a secure location!"
Write-Host "===================================================="
Write-Host ""

# Run the deployment
$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force

# Set debug and verbose preferences to continue
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Run the deployment with all parameters and force flag
& ./deploy.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -DomainName $DomainName `
    -Location $Location `
    -AdminUsername $AdminUsername `
    -AdminPassword $securePassword `
    -Force `
    -EnableVerbose

Write-Host ""
Write-Host "Deployment initiated. Check Azure Portal for progress." 