param appName string = uniqueString(resourceGroup().id) // Generate a unique string for the web app name
param sku string = 'P0v3' // Tier of the App Service plan
param linuxFxVersion string = 'PHP|8.4' // Runtime stack of the web app
param location string = resourceGroup().location // Location for all resources

var appServicePlanName = toLower('AppServicePlan-${appName}')
var webSiteName = toLower('mywebapp-${appName}')
var keyVaultName = toLower('kv-${appName}')
var storageAccountName = toLower('sto${appName}')
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

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${keyVault.name}/mySecret'
  properties: {
    value: 'blabla'
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

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
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
  identity: {
    type: 'SystemAssigned'  
  }
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
          mountPath: '/home/site/wwwroot/wwwroot/uploads/recipes' // path need to be checked using Kudu
        }
      }
      appSettings: [
        {
          name: 'MY_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${secret.properties.secretUriWithVersion})'
        }
      ]
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


// Attribution du rôle Key Vault Secrets User à l'identité managée système de la Web App
resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appService.identity.principalId  // Principal ID de l'identité système de la Web App
    principalType: 'ServicePrincipal'
  }
}
