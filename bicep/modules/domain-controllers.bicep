// Domain Controllers module for Windows Server 2025 Learning Lab
// Deploys two DC VMs and configures AD DS

param location string
param tags object
param prefix string

@secure()
param adminUsername string

@secure()
param adminPassword string

param domainName string
param subnetId string
param keyVaultName string

// VM configuration
var dc1Name = '${prefix}-dc1'
var dc2Name = '${prefix}-dc2'
var vmSize = 'Standard_D2s_v3' // 2 vCPUs, 8 GB RAM
var osDiskSizeGB = 128
var imageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2025-datacenter-azure-edition-smalldisk'
  version: 'latest'
}

// NIC configurations
resource dc1Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${dc1Name}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.4'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    enableIPForwarding: false
    enableAcceleratedNetworking: true
  }
}

resource dc2Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${dc2Name}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.5'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    enableIPForwarding: false
    enableAcceleratedNetworking: true
  }
}

// DC1 - Primary Domain Controller
resource dc1Vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: dc1Name
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
      computerName: dc1Name
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
          id: dc1Nic.id
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

// DC2 - Secondary Domain Controller
resource dc2Vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: dc2Name
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
      computerName: dc2Name
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
          id: dc2Nic.id
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

// Install AD DS on DC1 and create forest
resource dc1ConfigADDS 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: dc1Vm
  name: 'InstallADDS'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/install-addc1.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File install-addc1.ps1 -DomainName ${domainName} -AdminUser ${adminUsername} -AdminPassword ${adminPassword}'
    }
  }
}

// Set Static DNS on DC2 and promote to domain controller
resource dc2ConfigADDS 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: dc2Vm
  name: 'InstallADDS'
  location: location
  tags: tags
  dependsOn: [
    dc1ConfigADDS
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/install-addc2.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File install-addc2.ps1 -DomainName ${domainName} -AdminUser ${adminUsername} -AdminPassword ${adminPassword} -PrimaryDC 10.0.0.4'
    }
  }
}

// Install additional tools and setup demo environment
resource dc1ConfigTools 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: dc1Vm
  name: 'ConfigureTools'
  location: location
  tags: tags
  dependsOn: [
    dc1ConfigADDS
    dc2ConfigADDS
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/configure-dc-tools.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File configure-dc-tools.ps1 -DomainName ${domainName}'
    }
  }
}

// Install Certificate Services on DC1
resource dc1ConfigADCS 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: dc1Vm
  name: 'InstallADCS'
  location: location
  tags: tags
  dependsOn: [
    dc1ConfigTools
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/${prefix}/server-2025-learning-lab/main/scripts/install-adcs.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File install-adcs.ps1 -DomainName ${domainName}'
    }
  }
}

// Outputs
output dc1Name string = dc1Vm.name
output dc2Name string = dc2Vm.name
output dc1PrivateIp string = dc1Nic.properties.ipConfigurations[0].properties.privateIPAddress
output dc2PrivateIp string = dc2Nic.properties.ipConfigurations[0].properties.privateIPAddress 
