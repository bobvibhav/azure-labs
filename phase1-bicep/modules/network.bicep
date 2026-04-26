// modules/network.bicep
// Creates VNet and Subnet

param location string
param vnetName string
param vnetAddressPrefix string = '10.0.0.0/16'
param subnetName string = 'default'
param subnetPrefix string = '10.0.1.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Outputs — passed back to main.bicep
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
output vnetName string = vnet.name
