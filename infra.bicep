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
