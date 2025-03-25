// Client VM module for Windows Server 2025 Learning Lab
// Deploys a Windows 11 client VM to join the domain

param location string
param tags object
param prefix string

@secure()
param adminUsername string

@secure()
param adminPassword string

param domainName string
param subnetId string
param dcIpAddress string
param keyVaultName string

// VM configuration
var clientVmName = '${prefix}-client'
var vmSize = 'Standard_D2s_v3' // 2 vCPUs, 8 GB RAM
var osDiskSizeGB = 128
var imageReference = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-ent'
  version: 'latest'
}

// NIC configuration
resource clientVmNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${clientVmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.2.4'
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

// Client VM
resource clientVm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: clientVmName
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
      computerName: clientVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: clientVmNic.id
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

// Domain join and install tools
resource clientVmConfig 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: clientVm
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
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/setup-client.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File setup-client.ps1 -DomainName ${domainName} -AdminUser ${adminUsername} -AdminPassword ${adminPassword}'
    }
  }
}

// Outputs
output clientVmName string = clientVm.name
output clientVmPrivateIp string = clientVmNic.properties.ipConfigurations[0].properties.privateIPAddress 
