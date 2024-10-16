// param operatorIdentityName string
param identityprincipalId string = ''
param userObjectId string = ''

@description('The name of the Azure Storage Account')
param storageName string = ''

@description('The name of the Azure Kubernetes Service Cluster')
param clusterName string = ''

@description('The name of the Azure Container Registry')
param registryName string = ''


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (storageName != '' && identityprincipalId != '') {
  name: storageName
}

resource managedCluster 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' existing = if (clusterName != '' && userObjectId != '') {
  name: clusterName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-06-01-preview' existing = if (registryName != '') {
  name: registryName
}

var clusterAdminRole = resourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')
resource clusterAdminRoleAssignmentUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (clusterName != '' && userObjectId != '') {
  scope: managedCluster
  name: guid(userObjectId, managedCluster.id, clusterAdminRole)
  properties: { 
    roleDefinitionId: clusterAdminRole
    principalType: 'User'
    principalId: userObjectId
  }
}

resource clusterAdminRoleAssignmentIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (clusterName != '' && identityprincipalId != '') {
  scope: managedCluster
  name: guid(identityprincipalId, managedCluster.id, clusterAdminRole)
  properties: { 
    roleDefinitionId: clusterAdminRole
    principalType: 'ServicePrincipal'
    principalId: identityprincipalId
  }
}


// var policyDefinitionId = '/providers/Microsoft.Authorization/policySetDefinitions/c047ea8e-9c78-49b2-958b-37e56d291a44'
// resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
//   name: 'aksDeploymentSafeguardsAssignment'
//   scope: managedCluster
//   properties: {
//     displayName: 'AKS Deployment Safeguards'
//     #disable-next-line use-resource-id-functions
//     policyDefinitionId: policyDefinitionId
//     enforcementMode: 'DoNotEnforce'
//     parameters: {
//       effect: { value: 'Audit' }
//       allowedUsers: {
//         value: [] // Specify allowed users or leave empty array
//       }
//       allowedGroups: {
//         value: [] // Specify allowed groups or leave empty array
//       }
//       cpuLimit: {
//         value: '4' // Specify CPU limit, e.g., '1' for 1 core
//       }
//       memoryLimit: {
//         value: '4Gi' // Specify memory limit, e.g., '1Gi' for 1 Gibibyte
//       }
//       labels: {
//         value: [] // Specify required labels or leave empty object
//       }
//       allowedContainerImagesRegex: {
//         value: '.*' // Specify regex for allowed container images, e.g., '.*' to allow all
//       }
//       reservedTaints: {
//         value: [] // Specify reserved taints or leave empty array
//       }
//     }
//   }
// }

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

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acrPullRoleCluster 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (registryName != '' && clusterName != '') {
  name: guid(resourceGroup().id, managedCluster.id, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: managedCluster.properties.identityProfile.kubeletidentity.objectId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

var acrContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
resource acrPullRoleUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (registryName != '' && userObjectId != '') {
  name: guid(resourceGroup().id, userObjectId, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: userObjectId
    roleDefinitionId: acrContributorRoleDefinitionId
    principalType: 'User'
  }
}
