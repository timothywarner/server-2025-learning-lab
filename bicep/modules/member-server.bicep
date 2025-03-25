// Member Server module for Windows Server 2025 Learning Lab
// Deploys a member server with dev tools pre-installed

param location string
param tags object = {
  workload: 'ws2025-lab'
  environment: 'lab'
}
param prefix string

@secure()
param adminUsername string

@secure()
param adminPassword string

param domainName string
param subnetId string
param dcIpAddress string
param keyVaultName string

// VM configuration with dev tools requirements
var memberServerName = '${prefix}-mem01' // CAF naming: add number suffix
var vmSize = 'Standard_D4s_v3' // 4 vCPUs, 16 GB RAM for dev tools
var osDiskSizeGB = 256 // Increased for dev tools
var imageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2025-datacenter-azure-edition'  // Remove smalldisk for dev tools
  version: 'latest'
}

// NIC configuration
resource memberServerNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${memberServerName}-nic01' // CAF naming
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    enableIPForwarding: false
    enableAcceleratedNetworking: true
    dnsSettings: {
      dnsServers: [
        dcIpAddress
      ]
    }
  }
}

// Member Server VM
resource memberServerVm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: memberServerName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: osDiskSizeGB
      }
      imageReference: imageReference
    }
    osProfile: {
      computerName: memberServerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
        timeZone: 'UTC'  // Consistent timezone
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: memberServerNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Domain join and install dev tools
resource memberServerConfig 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: memberServerVm
  name: 'JoinDomainAndConfig'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/setup-member-server.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File setup-member-server.ps1 -DomainName ${domainName} -AdminUser ${adminUsername} -AdminPassword ${adminPassword} -InstallDevTools $true'
    }
  }
}

// Outputs
output memberServerName string = memberServerVm.name
output memberServerPrivateIp string = memberServerNic.properties.ipConfigurations[0].properties.privateIPAddress
output memberServerResourceId string = memberServerVm.id 
