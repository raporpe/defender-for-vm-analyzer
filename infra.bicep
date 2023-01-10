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

resource functionAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${functionAppName}-identity'
  location: location
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionAppIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'APP_REGISTRATION_SECRET_ID'
          value: 'enter your secret id here'
        }
        {
          name: 'APP_REGISTRATION_SECRET'
          value: 'enter your secret key here'
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

var roleAssignmentGUID = '9d33d8ba-2ffb-4709-a19c-ca3394e35aeb'

resource graphApiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentGUID
  scope: tenant()
  properties: {
    principalId: functionAppIdentity.id
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
}


resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}
