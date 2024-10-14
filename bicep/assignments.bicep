// param operatorIdentityName string
param identityprincipalId string = ''
param userObjectId string = ''

@description('The name of the Azure Storage Account')
param storageName string = ''

@description('The name of the Azure Kubernetes Service Cluster')
param clusterName string = ''


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (storageName != '' && identityprincipalId != '') {
  name: storageName
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' existing = if (clusterName != '' && userObjectId != '') {
  name: clusterName
}

var clusterAdminRole = resourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
resource clusterAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (clusterName != '' && userObjectId != '') {
  scope: managedCluster
  name: guid(userObjectId, managedCluster.id, clusterAdminRole)
  properties: { 
    roleDefinitionId: clusterAdminRole
    principalType: 'User'
    principalId: userObjectId
  }
}


var policyDefinitionId = resourceId('Microsoft.Authorization/policySetDefinitions', 'c047ea8e-9c78-49b2-958b-37e56d291a44')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'aksDeploymentSafeguardsAssignment'
  scope: managedCluster
  properties: {
    displayName: 'AKS Deployment Safeguards'
    policyDefinitionId: policyDefinitionId
    parameters: {} // Add any parameters required by the policy definition here
  }
}

var storageFileDataSmbShareReader = resourceId('Microsoft.Authorization/roleDefinitions', 'aba4ae5f-2193-4029-9191-0cb91df5e314')
resource storageRoleShare 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageName != '' && identityprincipalId != '') {
  scope: storageAccount
  name: guid(identityprincipalId, storageAccount.id, storageFileDataSmbShareReader)
  properties: {
    roleDefinitionId: storageFileDataSmbShareReader
    principalType: 'ServicePrincipal'
    principalId: identityprincipalId
  }
}

var storageBlobContributor = resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource storageRoleBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageName != '' && identityprincipalId != '') {
  scope: storageAccount
  name: guid(identityprincipalId, storageAccount.id, storageBlobContributor)
  properties: {
    roleDefinitionId: storageBlobContributor
    principalType: 'ServicePrincipal'
    principalId: identityprincipalId
  }
}

var storageTableContributor = resourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
resource storageRoleTable 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (storageName != '' && identityprincipalId != '') {
  scope: storageAccount
  name: guid(identityprincipalId, storageAccount.id, storageTableContributor)
  properties: {
    roleDefinitionId: storageTableContributor
    principalType: 'ServicePrincipal'
    principalId: identityprincipalId
  }
}
