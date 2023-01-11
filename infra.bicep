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

var storageAccountName = '${uniqueString(resourceGroup().id)}azfunctions'
var appName = 'defender-for-vm-analyzer-${uniqueString(resourceGroup().id)}'
var functionAppName = appName
var hostingPlanName = appName
var logAnalyticsName = appName


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

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
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

  dependsOn: [ storageAccount ]
  
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        //        DefaultEndpointsProtocol=https;AccountName=azureforvmanalyzert8c06;AccountKey=LbKFMYRRQqzHivsphtPsT89lKpi7kEJ//PgWlNT2mgy2ilBfmiXAs8SrzBA5MuyUadkZol0mPRVj+AStSBn3dQ==;EndpointSuffix=core.windows.net
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APP_REGISTRATION_SECRET_ID'
          value: 'enter your secret id here'
        }
        {
          name: 'APP_REGISTRATION_SECRET'
          value: 'enter your secret key here'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
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
    principalId: functionAppIdentity.properties.principalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
}


resource symbolicname 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  name: 'web'
  kind: 'web'
  parent: functionApp
  properties: {
    branch: 'main'
    repoUrl: 'https://github.com/raporpe/defender-for-vm-analyzer'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}
