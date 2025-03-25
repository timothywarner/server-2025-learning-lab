// Member Server module for Windows Server 2025 Learning Lab
// Deploys a member server with dev tools and admin center

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
param vmName string = 'mem1' // Parameter for member server name
param logAnalyticsWorkspaceId string = '' // Parameter for Log Analytics workspace ID

// VM configuration
var resourceName = '${prefix}-${vmName}' // Resource name (can be longer)
var computerName = vmName // Computer name must be 15 chars or less
var vmSize = 'Standard_D2s_v3' // 2 vCPUs, 8 GB RAM
var osDiskSizeGB = 128
var imageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2025-datacenter-azure-edition-smalldisk'
  version: 'latest'
}

// NIC configuration
resource memberServerNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${resourceName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
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

// Member Server VM
resource memberServerVm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: resourceName
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
      computerName: computerName
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

// Log Analytics agent for Member Server
resource memberServerLogAnalytics 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (!empty(logAnalyticsWorkspaceId)) {
  parent: memberServerVm
  name: 'MicrosoftMonitoringAgent'
  location: location
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: !empty(logAnalyticsWorkspaceId) ? reference(logAnalyticsWorkspaceId, '2022-10-01').customerId : ''
    }
    protectedSettings: {
      workspaceKey: !empty(logAnalyticsWorkspaceId) ? listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey : ''
    }
  }
}

// Domain join and install dev tools
resource memberServerConfig 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: memberServerVm
  name: 'JoinDomainAndConfig'
  location: location
  tags: tags
  dependsOn: !empty(logAnalyticsWorkspaceId) ? [memberServerLogAnalytics] : []
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "New-Item -Path C:\\Scripts -ItemType Directory -Force; Add-Content -Path C:\\Scripts\\setup-member-server.ps1 -Value \\"param ($DomainName, $AdminUser, $AdminPassword) Start-Transcript -Path C:\\Logs\\member-server-setup.log -Append; Write-Output \\"Starting member server configuration...\\"; Start-Sleep -Seconds 60; $securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force; $credential = New-Object System.Management.Automation.PSCredential(\\\\"$DomainName\\\\$AdminUser\\\\", $securePassword); Add-Computer -DomainName $DomainName -Credential $credential -Restart:$false -Force; Install-WindowsFeature -Name RSAT-AD-Tools, RSAT-DNS, Web-Server, Web-Mgmt-Tools; Write-Output \\"Configuration complete! Restart required.\\"; Stop-Transcript; Restart-Computer -Force\\"; C:\\Scripts\\setup-member-server.ps1 -DomainName ${domainName} -AdminUser ${adminUsername} -AdminPassword ${adminPassword}"'
    }
  }
}

// Outputs
output memberServerName string = resourceName
output memberServerPrivateIp string = memberServerNic.properties.ipConfigurations[0].properties.privateIPAddress
