targetScope = 'resourceGroup'

// @description('Name of the resource group')
// param resourceGroupName string = 'defender-for-vm-analyzer'
// 
// resource resourceGroup 'Microsoft.Resources/resourceGroups@2020-06-01' = {
//   name: resourceGroupName
//   location: location
// }

@description('Location for all resources.')
param location string = resourceGroup().location

var appName = 'defender-for-vm-analyzer-${uniqueString(resourceGroup().id)}'
var functionAppName = appName
var hostingPlanName = appName
var logAnalyticsName = appName
var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var functionWorkerRuntime = 'python'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

// The hosting for the function that will gather all the information
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~10'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}



resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
}
