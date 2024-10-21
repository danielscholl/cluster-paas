@description('The name of the Managed Cluster resource.')
param clusterName string

@description('The name of the resource group where the AKS cluster is located.')
param clusterResourceGroup string

@description('The blob container name.')
param blobContainer string

@description('The name of the storage account to be used.')
param storageAccountName string

@description('The resource group where the storage account is located.')
param storageAccountResourceGroup string

@description('The subscription ID where the storage account is located.')
param storageAccountSubscriptionId string

resource existingManagedCluster 'Microsoft.ContainerService/managedClusters@2024-04-02-preview' existing = {
  name: clusterName
  scope: resourceGroup(clusterResourceGroup)
}

resource azureAksBackupExtension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'azure-aks-backup'
  scope: existingManagedCluster
  properties: {
    autoUpgradeMinorVersion: true
    releaseTrain: 'stable'
    extensionType: 'microsoft.dataprotection.kubernetes'
    configurationSettings: {
      blobContainer: blobContainer
      storageAccount: storageAccountName
      storageAccountResourceGroup: storageAccountResourceGroup
      storageAccountSubscriptionId: storageAccountSubscriptionId
    }
  }
}
