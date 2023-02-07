targetScope = 'resourceGroup'

param rg object
param subscription object
param baseName string
param executionIntervalMinutes int

var location = rg.location
var storageAccountName = 'analyzer${uniqueString(rg.resourceId)}'
var functionAppName = '${baseName}-func'
var hostingPlanName = '${baseName}-hostingplan'
var logAnalyticsName = '${baseName}-loganalytics'
var managedIdentityName = '${baseName}-identity'
var appInsightsName = '${baseName}-appinsights'

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
  name: managedIdentityName
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

  dependsOn: [
    storageAccount
  ]

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

output functionAppIdentityId object = functionAppIdentity


resource config 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
    FUNCTIONS_WORKER_RUNTIME: 'python'
    WEBSITE_CONTENTSHARE: toLower(functionAppName)
    SUBSCRIPTION_ID: subscription.subscriptionId
    Project: 'defender-for-vm-analyzer'
    WEBSITE_RUN_FROM_PACKAGE: packageURL
    FUNCTIONS_EXTENSION_VERSION: '~4'
    AZURE_CLIENT_ID: functionAppIdentity.properties.clientId
    DEBUG: 'false'
    DEBUG_ANONYMOUS_IDENTITY: uniqueString(rg.resourceId)
    EXECUTION_INTERVAL_MINUTES: string(executionIntervalMinutes)
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
}

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: '${baseName}-dashboard'
  location: rg.location
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              colSpan: 6
              rowSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'partTitle'
                  value: 'Running Databricks VMs'
                  isOptional: true
                }
                {
                  name: 'query'
                  value: 'resources\r\n| where type == "microsoft.compute/virtualmachines"\r\n| where subscriptionId == "${subscription.subscriptionId}"\r\n| mv-expand tags\r\n| project name, tags\r\n| extend tagKey = tostring(bag_keys(tags)[0])\r\n| extend tagValue = tostring(tags[tagKey])\r\n| where tagKey =~ "Vendor"\r\n| summarize count() by tagValue\r\n'
                  isOptional: true
                }
                {
                  name: 'chartType'
                  value: 2
                  isOptional: true
                }
                {
                  name: 'isShared'
                  isOptional: true
                }
                {
                  name: 'queryId'
                  value: '385824b2-4ec4-4209-9eda-d840eb21452f'
                  isOptional: true
                }
                {
                  name: 'formatResults'
                  isOptional: true
                }
                {
                  name: 'queryScope'
                  value: {
                    scope: 0
                    values: []
                  }
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/ArgQueryChartTile'
              settings: {
              }
            }
          }
          {
            position: {
              x: 6
              y: 0
              colSpan: 6
              rowSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'partTitle'
                  value: 'Non-databricks VMs'
                  isOptional: true
                }
                {
                  name: 'query'
                  value: 'resources\r\n| where type == "microsoft.compute/virtualmachines"\r\n| where subscriptionId == "${subscription.subscriptionId}"\r\n| project name, resourceGroup, location\r\n| summarize count() by resourceGroup'
                  isOptional: true
                }
                {
                  name: 'chartType'
                  value: 2
                  isOptional: true
                }
                {
                  name: 'isShared'
                  isOptional: true
                }
                {
                  name: 'queryId'
                  value: '385824b2-4ec4-4209-9eda-d840eb21452f'
                  isOptional: true
                }
                {
                  name: 'formatResults'
                  isOptional: true
                }
                {
                  name: 'queryScope'
                  value: {
                    scope: 0
                    values: []
                  }
                  isOptional: true
                }
              ]
              type: 'Extension/HubsExtension/PartType/ArgQueryChartTile'
              settings: {
              }
              partHeader: {
                title: 'VM'
                subtitle: ''
              }
            }
          }
          {
            position: {
              x: 6
              y: 5
              colSpan: 6
              rowSpan: 5
            }
            metadata: {
              inputs: [
                {
                  name: 'resourceTypeMode'
                  isOptional: true
                }
                {
                  name: 'ComponentId'
                  isOptional: true
                }
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      '/subscriptions/${subscription.subscriptionId}/resourcegroups/${baseName}/providers/microsoft.operationalinsights/workspaces/${logAnalyticsName}'
                    ]
                  }
                  isOptional: true
                }
                {
                  name: 'PartId'
                  value: '7a9ba5c4-8f49-40a7-8368-03d70117fed7'
                  isOptional: true
                }
                {
                  name: 'Version'
                  value: '2.0'
                  isOptional: true
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                  isOptional: true
                }
                {
                  name: 'DashboardId'
                  isOptional: true
                }
                {
                  name: 'DraftRequestParameters'
                  isOptional: true
                }
                {
                  name: 'Query'
                  value: 'let defenderForVMHourlyCost = 0.02;\nlet TotalHours = toscalar(AppTraces \n| where Message startswith "Billable Databricks VMs: "\n| project TimeGenerated, DatabricksVMCount = extract("[0-9]+", 0, Message)\n| summarize max(DatabricksVMCount) by bin(TimeGenerated, 1h)\n| summarize TotalHours = sum(toint(max_DatabricksVMCount)));\nprint TotalCost = TotalHours*defenderForVMHourlyCost\n'
                  isOptional: true
                }
                {
                  name: 'ControlType'
                  value: 'AnalyticsGrid'
                  isOptional: true
                }
                {
                  name: 'SpecificChart'
                  isOptional: true
                }
                {
                  name: 'PartTitle'
                  value: 'Analytics'
                  isOptional: true
                }
                {
                  name: 'PartSubTitle'
                  value: logAnalyticsName
                  isOptional: true
                }
                {
                  name: 'Dimensions'
                  isOptional: true
                }
                {
                  name: 'LegendOptions'
                  isOptional: true
                }
                {
                  name: 'IsQueryContainTimeRange'
                  value: false
                  isOptional: true
                }
              ]
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              settings: {
              }
              partHeader: {
                title: 'Defender for server cost for Databricks VMs'
                subtitle: 'The cost is in dollars ($)'
              }
            }
          }
          {
            position: {
              x: 0
              y: 5
              colSpan: 6
              rowSpan: 5
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  content: '__My data__\n\nThis tile lets you put custom content on your dashboard. It supports plain text, __Markdown__, and even limited HTML like images <img width=\'10\' src=\'https://portal.azure.com/favicon.ico\'/> and <a href=\'https://azure.microsoft.com\' target=\'_blank\'>links</a> that open in a new tab.\n'
                  title: 'Information'
                  subtitle: 'Project GitHub README.md'
                  markdownSource: 2
                  markdownUri: 'https://raw.githubusercontent.com/raporpe/defender-for-vm-analyzer/main/README.md'
                }
              }
              partHeader: {
                title: 'Information'
                subtitle: 'Project GitHub Readme'
              }
            }
          }
      ]
    }
      
    ]
    metadata: {
      model: {
        timeRange: {
          value: {
            relative: {
              duration: 24
              timeUnit: 1
            }
          }
          type: 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
        }
        filterLocale: {
          value: 'en-us'
        }
        filters: {
          value: {
            MsPortalFx_TimeRange: {
              model: {
                format: 'utc'
                granularity: 'auto'
                relative: '30d'
              }
              displayCache: {
                name: 'UTC Time'
                value: 'Past 30 days'
              }
              filteredPartIds: [
                'StartboardPart-LogsDashboardPart-807fe50a-e2d8-4b53-abd1-acce9ca0f2f1'
              ]
            }
          }
        }
      }
    }
  }
}
