// Key Vault module for Windows Server 2025 Learning Lab
// Securely stores credentials for the environment

param location string
param tags object
param prefix string

param adminUsername string

@secure()
param adminPassword string

// Key Vault configuration
var kvName = '${prefix}-kv-${uniqueString(resourceGroup().id)}'

// Create Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    accessPolicies: []
  }
}

// Store admin username secret
resource usernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'adminUsername'
  properties: {
    value: adminUsername
  }
}

// Store admin password secret
resource passwordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'adminPassword'
  properties: {
    value: adminPassword
  }
}

// Outputs
output keyVaultName string = kvName
output keyVaultId string = keyVault.id 
