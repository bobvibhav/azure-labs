// modules/vm.bicep
// Creates Windows Server VM

param location string
param vmName string
param vmSize string = 'Standard_B2ts_v2'
param adminUsername string
@secure()
param adminPassword string
param subnetId string
param environment string = 'Development'

var nicName = '${vmName}-nic'
var publicIpName = '${vmName}-pip'
var osDiskName = '${vmName}-osdisk'

// Public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: {
    Environment: environment
    CreatedBy: 'Bicep'
  }
}

// Network Interface Card
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
  tags: {
    Environment: environment
    CreatedBy: 'Bicep'
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize                    // parameter — easy to change
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'   // Premium SSD
        }
        deleteOption: 'Delete'                // disk deleted with VM
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true                         // boot diagnostics enabled
      }
    }
  }
  tags: {
    Environment: environment
    CreatedBy: 'Bicep'
    Owner: 'vibhav.mishra'
  }
}

output vmId string = vm.id
output vmName string = vm.name
output publicIpAddress string = publicIp.properties.ipAddress
