// storage.bicep
// Deploys a Storage Account with configurable parameters

// ── Parameters ────────────────────────────────────────────────────────────
@description('Name of the storage account - must be globally unique, lowercase, 3-24 chars')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Azure region where storage account will be deployed')
param location string = resourceGroup().location

@description('Storage account SKU - redundancy type')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Premium_LRS'
])
param storageSku string = 'Standard_ZRS'

@description('Environment tag')
@allowed([
  'Development'
  'Staging'
  'Production'
])
param environment string = 'Development'

// ── Variables ─────────────────────────────────────────────────────────────
var tags = {
  Environment: environment
  Owner: 'vibhav.mishra'
  CreatedBy: 'Bicep'
  Project: 'AzureLabs'
}

// ── Resources ─────────────────────────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageSku
  }
  tags: tags
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true        // forces HTTPS - security best practice
    allowBlobPublicAccess: false          // no anonymous public access
    minimumTlsVersion: 'TLS1_2'          // enforce minimum TLS version
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoint string = storageAccount.properties.primaryEndpoints.blob
