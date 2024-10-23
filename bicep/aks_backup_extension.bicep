@description('The name of the Managed Cluster resource.')
param clusterName string

@description('The blob container name.')
param blobContainer string = 'backup'

@description('The name of the storage account to be used.')
param storageAccountName string

@description('The name of the backup vault to be used.')
param backupVaultName string

resource existingManagedCluster 'Microsoft.ContainerService/managedClusters@2024-04-02-preview' existing = {
  name: clusterName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource backupVault 'Microsoft.DataProtection/backupVaults@2024-04-01' existing = {
  name: backupVaultName
}

// Configure the AKS Backup Extension
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
      #disable-next-line use-resource-id-functions
      'configuration.backupStorageLocation.config.subscriptionId': subscription().subscriptionId
      #disable-next-line use-resource-id-functions
      'credentials.tenantId': tenant().tenantId
    }
  }
}

// Role Assignment for Backup Extension to act as Contributor to Storage Account
resource roleContributorExtensionToStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, azureAksBackupExtension.id, 'Storage Account Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Storage Account Contributor
    principalId: azureAksBackupExtension.properties.aksAssignedIdentity.principalId
  }
}

// Role Assignment for Backup Vault as Reader over AKS Cluster
resource roleReaderVaultToCluster 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(backupVault.name, existingManagedCluster.name, 'Reader')
  scope: existingManagedCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader role definition ID
    principalId: backupVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment for Backup Vault as Reader over Snapshot Resource Group
resource roleReaderVaultToResourceGroup 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(backupVault.name, resourceGroup().id, 'Reader')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader role definition ID
    principalId: backupVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment for Backup Vault as Disk Snapshot Contributor
resource roleReaderVaultToResourceGroupDiskSnapshot 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(backupVault.name, resourceGroup().id, 'Disk Snapshot Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7efff54f-a5b4-42b5-a1c5-5411624893ce') // Disk Snapshot Contributor role definition ID
    principalId: backupVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment for Backup Vault as Data Operator for Managed Disks
resource roleReaderVaultToResourceGroupDataOperator 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(backupVault.name, resourceGroup().id, 'Data Operator for Managed Disks')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '959f8984-c045-4866-89c7-12bf9737be2e') // Data Operator for Managed Disks role definition ID
    principalId: backupVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment for Backup Vault as Storage Blob Data Reader
resource roleReaderVaultToStorageBlobDataReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(backupVault.name, storageAccount.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Dagta Reader role definition ID
    principalId: backupVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment for AKS Cluster as Contributor over the Snapshot Resource Group
resource roleContributorClusterToResourceGroup 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(existingManagedCluster.name, resourceGroup().id, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role definition ID
    principalId: existingManagedCluster.properties.identityProfile.kubeletIdentity.objectId
    principalType: 'ServicePrincipal'
  }
}


// Role Assignment for AKS Cluster as Backup Operator to the Vault
resource roleBackupOperatorClusterToVault 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(existingManagedCluster.name, azureAksBackupExtension.id, 'Backup Operator')
  scope: backupVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00c29273-979b-4161-815c-10b084fb9324') // Backup Operator role definition ID
    principalId: existingManagedCluster.properties.identityProfile.kubeletIdentity.objectId
    principalType: 'ServicePrincipal'
  }
}
