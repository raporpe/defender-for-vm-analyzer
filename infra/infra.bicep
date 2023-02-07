targetScope = 'subscription'

@description('Interval of time to wait before evaluating the VMs (i.e., every how many minutes you want the function to evaluate the running VMs). If there are many VMs in the subscription, it might be possible the Azure Management API limit is reached; consider a high minute interval for these cases.')
@minValue(1)
@maxValue(60)
param executionIntervalMinutes int = 5


@description('The name of the resource group that will keep the analyzer.')
var baseName = 'def-vm-analyzer-${substring(uniqueString(subscription().subscriptionId), 0, 5)}'

resource mainRG 'Microsoft.Resources/resourceGroups@2020-06-01' = {

  name: baseName
  location: deployment().location

}


module resourceGroupContents 'infra2.bicep' = {
  name: 'mainRG'
  scope: mainRG
  params: {
    rg: mainRG
    subscription: subscription()
    baseName: baseName
    executionIntervalMinutes: executionIntervalMinutes
  }
}


// The custom role that only allows to read VMs metadata

resource vmReadRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(tenant().tenantId)
  scope: subscription()
  properties: {
    assignableScopes: [
        'subscriptions/${subscription().subscriptionId}'
    ]
    description: 'Read VM metadata'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/instanceView/read'
        ]
      }
    ]
    roleName: 'def-vm-analyzer-read-vm-metadata' 
  }
}


resource graphApiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mainRG.id)
  scope: subscription()
  properties: {
    principalId: resourceGroupContents.outputs.functionAppIdentityId.properties.principalId
    roleDefinitionId: vmReadRole.id
  }
}

  