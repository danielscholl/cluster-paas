@description('The name of the Managed Cluster resource.')
param clusterName string

@description('The blob container name.')
param blobContainer string = 'backup'

@description('The name of the storage account to be used.')
param storageAccountName string

resource existingManagedCluster 'Microsoft.ContainerService/managedClusters@2024-04-02-preview' existing = {
  name: clusterName
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
      storageAccountResourceGroup: resourceGroup().name
      storageAccountSubscriptionId: subscription().subscriptionId
    }
  }
}
