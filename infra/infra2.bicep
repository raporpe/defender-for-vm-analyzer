targetScope = 'resourceGroup'

param rg object
param subscription object

var location = rg.location
var storageAccountName = '${uniqueString(rg.resourceId)}azfunctions'
var appName = 'defender-for-vm-analyzer-${uniqueString(rg.resourceId)}'
var functionAppName = appName
var hostingPlanName = appName
var logAnalyticsName = appName
var packageURL = 'https://github.com/raporpe/defender-for-vm-analyzer/releases/latest/download/release.zip'



// The hosting for the function that will gather all the information
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    reserved: true
  }
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

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionAppIdentity.id}': {}
    }
  }

  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'Python|3.9'
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: packageURL
        }
        {
          name: 'SUBSCRIPTION_ID'
          value: subscription.subscriptionId
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

output functionAppIdentityId object = functionAppIdentity

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
}



resource githubRepositoryFunctionCode 'Microsoft.Web/sites/sourcecontrols@2022-03-01' = {
  name: 'web'
  parent: functionApp

  properties: {
    branch: 'main'
    isManualIntegration: true
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

