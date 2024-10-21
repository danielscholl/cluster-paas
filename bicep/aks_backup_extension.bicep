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
      'configuration.backupStorageLocation.bucket': blobContainer
      'configuration.backupStorageLocation.config.storageAccount': storageAccountName
      'configuration.backupStorageLocation.config.resourceGroup': resourceGroup().name
      'configuration.backupStorageLocation.config.subscriptionId': subscription().subscriptionId
      'credentials.tenantId': tenant().tenantId
    }
  }
}
