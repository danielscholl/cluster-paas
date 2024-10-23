param backupVaultName string
param kubernetesClusterId string
param backupPolicyId string
param location string
param snapshotResourceGroupId string


resource backupVault 'Microsoft.DataProtection/backupVaults@2022-11-01-preview' existing = {
  name: backupVaultName
}

resource backupInstanceKubernetes 'Microsoft.DataProtection/backupVaults/backupInstances@2022-11-01-preview' = {
  name: 'backup-instance-aks' // Backup Instance name within the Backup Vault
  parent: backupVault // Parent is the Backup Vault
  properties: {
    datasourceAuthCredentials: {
      objectType: 'SecretStoreBasedAuthCredentials'
      secretStoreResource: {
        secretStoreType: 'string'
        uri: 'string'
        value: 'string'
      }// Assuming Managed Identity for the AKS cluster
    }
    dataSourceInfo: {
      datasourceType: 'Microsoft.Kubernetes' // Data source is a Kubernetes cluster
      objectType: 'Datasource' // Datasource object
      resourceID: kubernetesClusterId
      resourceLocation: location
      resourceName: 'akscluster'
      resourceType: 'Microsoft.ContainerService/managedClusters'
      resourceUri: kubernetesClusterId
    }
    friendlyName: 'AKS Backup Instance' // A friendly name for the backup instance
    objectType: 'BackupInstance' // Object type of the instance
    policyInfo: {
      policyId: backupPolicyId
      policyParameters: {
        backupDatasourceParametersList: [
          {
            objectType: 'KubernetesClusterBackupDatasourceParameters'
            excludedNamespaces: [
              'string'
            ]
            excludedResourceTypes: [
              'string'
            ]
            includeClusterScopeResources: true
            includedNamespaces: [
              'string'
            ]
            includedResourceTypes: [
              'string'
            ]
            labelSelectors: [
              'string'
            ]
            snapshotVolumes: true
          }
        ]
        dataStoreParametersList: [
          {
            dataStoreType: 'OperationalStore'
            objectType: 'AzureOperationalStoreParameters'
              resourceGroupId: snapshotResourceGroupId
          }
        ]
      }
    }
    validationType: 'None' // You can adjust this based on your scenario
  }
  dependsOn: [
    // Dependencies such as backup vault creation, policy creation, and AKS role assignments
  ]
}
