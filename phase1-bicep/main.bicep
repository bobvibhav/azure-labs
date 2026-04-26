// main.bicep
// Orchestrates network and VM modules

param location string = resourceGroup().location
param environment string = 'Development'

@description('VM admin username')
param adminUsername string = 'vibhavadmin'

@description('VM admin password')
@secure()
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_B2ts'

// Call network module first
module network './modules/network.bicep' = {
  name: 'networkDeploy'
  params: {
    location: location
    vnetName: 'vnet-vibhav-${environment}'
    vnetAddressPrefix: '10.0.0.0/16'
    subnetName: 'subnet-default'
    subnetPrefix: '10.0.1.0/24'
  }
}

// Call VM module — depends on network completing first
module vm './modules/vm.bicep' = {
  name: 'vmDeploy'
  dependsOn: [network]              // network must finish before VM starts
  params: {
    location: location
    vmName: 'vm-bicep-001'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    subnetId: network.outputs.subnetId   // passing subnet ID from network module
    environment: environment
  }
}

// Outputs from both modules
output vnetName string = network.outputs.vnetName
output vmName string = vm.outputs.vmName
output vmPublicIp string = vm.outputs.publicIpAddress
