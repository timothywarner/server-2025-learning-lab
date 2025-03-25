# Windows Server 2025 Learning Lab
# Deployment Script

param(
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$DomainName = "winlab2025",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$AdminPassword
)

# Banner
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          Windows Server 2025 Learning Lab Deployer         " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check if user is logged in to Azure
$context = Get-AzContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Host "You are not logged in to Azure. Connecting..." -ForegroundColor Yellow
    Connect-AzAccount
} else {
    Write-Host "Connected to Azure as: $($context.Account)" -ForegroundColor Green
    Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor Green
}

# Ask for admin username if not provided
if (-not $AdminUsername) {
    $AdminUsername = Read-Host "Enter admin username (must be complex and 8+ characters)"
    while ($AdminUsername.Length -lt 8) {
        Write-Host "Username must be at least 8 characters long." -ForegroundColor Red
        $AdminUsername = Read-Host "Enter admin username (must be complex and 8+ characters)"
    }
}

# Generate random password if not provided
if (-not $AdminPassword) {
    $generateRandom = Read-Host "Would you like to generate a random password? (Y/N)"
    if ($generateRandom -eq "Y") {
        # Generate a complex random password
        $passwordLength = 16
        $alphabets = "abcdefghijklmnopqrstuvwxyz"
        $upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $numbers = "0123456789"
        $special = "!@#$%^&*()_+-=[]{}|;':,./<>?"
        
        $password = ""
        $password += ($alphabets | Get-Random) # at least one lowercase
        $password += ($upperCase | Get-Random) # at least one uppercase
        $password += ($numbers | Get-Random) # at least one number
        $password += ($special | Get-Random) # at least one special char
        
        # Fill the rest randomly
        $allChars = $alphabets + $upperCase + $numbers + $special
        $remainingLength = $passwordLength - 4
        for ($i = 0; $i -lt $remainingLength; $i++) {
            $password += ($allChars | Get-Random)
        }
        
        # Shuffle the password
        $passwordArray = $password.ToCharArray()
        $shuffledArray = $passwordArray | Get-Random -Count $passwordArray.Length
        $password = -join $shuffledArray
        
        $AdminPassword = ConvertTo-SecureString $password -AsPlainText -Force
        Write-Host "Generated password: $password" -ForegroundColor Green
        Write-Host "*** Please save this password securely! ***" -ForegroundColor Yellow
    } else {
        # Ask for password
        $AdminPassword = Read-Host -AsSecureString "Enter admin password (must be complex and 12+ characters)"
    }
}

# Prompt for Azure region
$regions = @(
    "eastus", "eastus2", "southcentralus", "westus2", "westus3",
    "australiaeast", "southeastasia", "northeurope", "swedencentral", 
    "uksouth", "westeurope", "centralus", "southafricanorth", 
    "centralindia", "eastasia", "japaneast", "koreacentral", 
    "canadacentral", "francecentral", "germanywestcentral", 
    "italynorth", "norwayeast", "polandcentral", "switzerlandnorth", 
    "uaenorth", "brazilsouth", "qatarcentral"
)

$selectedRegion = Read-Host "Enter Azure region (press Enter for default: $Location)"
if ($selectedRegion -and $regions -contains $selectedRegion) {
    $Location = $selectedRegion
}

# Confirm deployment
Write-Host ""
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
Write-Host "Region: $Location" -ForegroundColor White
Write-Host "Domain Name: $DomainName" -ForegroundColor White
Write-Host "Admin Username: $AdminUsername" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Ready to deploy Windows Server 2025 Learning Lab? (Y/N)"
if ($confirmation -ne "Y") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit
}

# Set current directory as the bicep working directory
$workingDirectory = $PSScriptRoot

# Check if there's an Azure subscription available
try {
    $subscriptions = Get-AzSubscription
    if (-not $subscriptions) {
        Write-Host "No Azure subscriptions found. Please create one or check your login credentials." -ForegroundColor Red
        exit
    }
} catch {
    Write-Host "Error checking subscriptions: $_" -ForegroundColor Red
    exit
}

# Deploy bicep template
Write-Host "Starting deployment..." -ForegroundColor Cyan

try {
    # Convert SecureString password to plain text for parameter
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    # Deploy using Azure CLI
    Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
    az deployment sub create `
        --name "WinServer2025Lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --location $Location `
        --template-file "$workingDirectory\bicep\main.bicep" `
        --parameters location=$Location `
        --parameters domainName=$DomainName `
        --parameters adminUsername=$AdminUsername `
        --parameters adminPassword=$plainPassword
    
    # Clean up the plain text password
    $plainPassword = "XXXXXXXX"
} catch {
    Write-Host "Error during deployment: $_" -ForegroundColor Red
    exit
}

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Access Information:" -ForegroundColor Cyan
Write-Host "-----------------" -ForegroundColor Cyan
Write-Host "1. Deploy outputs contain connection information." -ForegroundColor White
Write-Host "2. Use Azure Bastion to connect to your VMs." -ForegroundColor White
Write-Host "3. Your credentials are stored in the created Key Vault." -ForegroundColor White
Write-Host ""
Write-Host "Enjoy your Windows Server 2025 Learning Lab!" -ForegroundColor Green 