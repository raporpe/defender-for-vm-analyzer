targetScope = 'subscription'


@description('Location for all resources.')
param location string


@description('The name of the resource group that will keep the analyzer.')
var resourceGroupNameAnalyzer = 'defender-for-vm-analyzer-${uniqueString(subscription().subscriptionId)}'

resource mainRG 'Microsoft.Resources/resourceGroups@2020-06-01' = {

  name: resourceGroupNameAnalyzer
  location: location

}


module resourceGroupContents 'infra2.bicep' = {
  name: 'mainRG'
  scope: mainRG
  params: {
    rg: mainRG
    subscription: subscription()
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
    roleName: 'defender-for-analyzer-read-vm-metadata' 
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

  