@description('The name of the Azure Storage Account')
param storageName string = ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (storageName != '') {
  name: storageName
}

resource updateNetworkRules 'Microsoft.Storage/storageAccounts@2022-09-01' =  {
  name: storageAccount.name  // Reference the existing storage account's name
  properties: {
    networkAcls: {
      defaultAction: 'Deny'  // Deny access unless explicitly allowed
      bypass: 'AzureServices'  // Allow access from Azure services (e.g., Azure Functions)
    }
  }
}
