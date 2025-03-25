// Windows Server 2025 Learning Lab
// Main deployment file

targetScope = 'subscription'

// Parameters
@description('The Azure region for deploying resources')
param location string = deployment().location

@description('Optional domain name for the Active Directory domain')
@minLength(2)
@maxLength(15)
param domainName string = 'winlab2025'

@description('Tags to apply to all resources')
param tags object = {
  Project: 'WinServer2025Lab'
  Environment: 'Lab'
  ProvisionedBy: 'Bicep'
}

@description('Admin username for all VMs')
@secure()
param adminUsername string

@description('Admin password for all VMs')
@secure()
param adminPassword string

@description('Resource name prefix to ensure uniqueness')
param prefix string = 'ws2025${uniqueString(subscription().id)}'

// Variables
var rgName = '${prefix}-rg'

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
  tags: tags
}

// Networking module
module networking 'modules/networking.bicep' = {
  name: 'networkingDeployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    prefix: prefix
  }
}

// Key Vault module
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    prefix: prefix
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Domain Controllers
module domainControllers 'modules/domain-controllers.bicep' = {
  name: 'dcDeployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    prefix: prefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    subnetId: networking.outputs.adSubnetId
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Member Server
module memberServer 'modules/member-server.bicep' = {
  name: 'memberServerDeployment'
  scope: resourceGroup
  dependsOn: [
    domainControllers
  ]
  params: {
    location: location
    tags: tags
    prefix: prefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    subnetId: networking.outputs.serverSubnetId
    dcIpAddress: domainControllers.outputs.dc1PrivateIp
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Client VM
module clientVM 'modules/client-vm.bicep' = {
  name: 'clientVmDeployment'
  scope: resourceGroup
  dependsOn: [
    domainControllers
  ]
  params: {
    location: location
    tags: tags
    prefix: prefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainName: domainName
    subnetId: networking.outputs.clientSubnetId
    dcIpAddress: domainControllers.outputs.dc1PrivateIp
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// Outputs
output resourceGroupName string = resourceGroup.name
output keyVaultName string = keyVault.outputs.keyVaultName
output domain string = domainName
output dc1Name string = domainControllers.outputs.dc1Name
output dc2Name string = domainControllers.outputs.dc2Name
output memberServerName string = memberServer.outputs.memberServerName
output clientVmName string = clientVM.outputs.clientVmName
output deploymentInstructions string = 'Use Azure Bastion to connect to VMs. Credentials are stored in Key Vault ${keyVault.outputs.keyVaultName}' 
