param webAppName string = uniqueString(resourceGroup().id) // Generate a unique string for the web app name
param sku string = 'P0v3' // Tier of the App Service plan
param linuxFxVersion string = 'PHP|8.4' // Runtime stack of the web app
param location string = resourceGroup().location // Location for all resources
param storageAccountNamePrefix string // Prefix for the storage account name
param keyVaultNamePrefix string // Prefix for the Key Vault name

var appServicePlanName = toLower('AppServicePlan-${webAppName}')
var webSiteName = toLower('mywebapp-${webAppName}')
var keyVaultName = toLower('${keyVaultNamePrefix}${uniqueString(resourceGroup().id)}')
var storageAccountName = toLower('${storageAccountNamePrefix}${uniqueString(resourceGroup().id)}')
var fileShareName = 'recipes'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: storageAccount
  name: 'default/${fileShareName}'
  properties: {
    accessTier: 'TransactionOptimized'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
  kind: 'linux'
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: webSiteName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      azureStorageAccounts: {
        recipes: {
          type: 'AzureFiles'
          accountName: storageAccount.name
          shareName: fileShareName
          accessKey: storageAccount.listKeys().keys[0].value
          mountPath: '/wwwroot/wwwroot/uploads/recipes'
        }
      }
    }
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: appService
  name: 'staging'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
    }
  }
}
