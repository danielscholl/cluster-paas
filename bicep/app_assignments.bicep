// param operatorIdentityName string
param identityprincipalId string

@description('The name of the Azure Key Vault')
param kvName string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: kvName
}

var keyVaultSecretsUser = resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (kvName != '') {
  scope: keyVault
  name: guid(identityprincipalId, keyVault.id, keyVaultSecretsUser)
  properties: {
    roleDefinitionId: keyVaultSecretsUser
    principalType: 'ServicePrincipal'
    principalId: identityprincipalId
  }
}





