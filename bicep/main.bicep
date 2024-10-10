targetScope = 'resourceGroup'
metadata name = 'Managed Kubernetes.'
metadata description = 'This instance deploys a managed Kubernetes cluster.'


@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Server Size.')
param vmSize string = 'Standard_DS2_v2'

@description('Internal Configuration Object')
var configuration = {
  name: 'main'
  displayName: 'Main Resources'
  logs: {
    sku: 'PerGB2018'
    retention: 30
  }
}

@description('Unique ID for the resource group')
var rg_unique_id = '${replace(configuration.name, '-', '')}${uniqueString(resourceGroup().id, configuration.name)}'

//*****************************************************************//
//  Identity Resources                                             //
//*****************************************************************//
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${configuration.name}-user-managed-identity'
  params: {
    // Required parameters
    name: rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }
  }
}


//*****************************************************************//
//  Monitoring Resources                                           //
//*****************************************************************//
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: '${configuration.name}-log-analytics'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuName: configuration.logs.sku
  }
}


//*****************************************************************//
//  Configuration Resources                                        //
//*****************************************************************//

@description('The list of secrets to persist to the Key Vault')
var vaultSecrets = [ 
  {
    secretName: 'tenant-id'
    secretValue: subscription().tenantId
  }
  {
    secretName: 'subscription-id'
    secretValue: subscription().subscriptionId
  }
]

module keyvault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: '${configuration.name}-keyvault'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    
    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    enablePurgeProtection: false
    publicNetworkAccess: 'Disabled'
    
    // Configure RBAC
    enableRbacAuthorization: true
    roleAssignments: [{
      roleDefinitionIdOrName: 'Key Vault Secrets User'
      principalId: identity.outputs.principalId
      principalType: 'ServicePrincipal'
    }]

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }

    // Configure Secrets
    secrets: [
      for secret in vaultSecrets: {
        name: secret.secretName
        value: secret.secretValue
      }
    ]
  }
}

module configurationStore 'br/public:avm/res/app-configuration/configuration-store:0.5.0' = {
  name: '${configuration.name}-appconfig'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id    
    location: location

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    enablePurgeProtection: false
  }
}


//*****************************************************************//
//  Storage Resources                                             //
//*****************************************************************//
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: 'storageAccountDeployment'
  params: {
    // Required parameters
    name: 'ssamin001'
    // Non-required parameters
    allowBlobPublicAccess: false
    location: '<location>'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

var systemPoolProfile = {
  name: 'systempool'
  mode: 'System'
  osType: 'Linux'
  osSKU: 'AzureLinux'
  type: 'VirtualMachineScaleSets'
  osDiskType: 'Managed'
  osDiskSizeGB: 128
  vmSize: vmSize
  count: 1
  minCount: 1
  maxCount: 3
  maxPods: 30
  enableAutoScaling: true

  nodeTaints: [
    'CriticalAddonsOnly=true:NoSchedule'
  ]
}


//*****************************************************************//
//  Cluster Resources                                             //
//*****************************************************************//

module managedCluster 'br/public:avm/res/container-service/managed-cluster:0.3.0' = {
  name: '${configuration.name}-cluster'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location

    // Assign Tags
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuTier: 'Standard'

    primaryAgentPoolProfile: [
      systemPoolProfile
    ]

    networkPlugin: 'azure'
    networkPluginMode: 'overlay'

    enablePrivateCluster: false
    disableLocalAccounts: true
    enableAzureDefender: true
    omsAgentEnabled: true

    enableOidcIssuerProfile: true
    enableWorkloadIdentity: true
    enableImageCleaner: true
    enableContainerInsights: true
    enableKeyvaultSecretsProvider: true
    

    // Non-required parameters
    maintenanceConfiguration: {
      maintenanceWindow: {
        schedule: {
          daily: null
          weekly: {
            intervalWeeks: 1
            dayOfWeek: 'Sunday'
          }
          absoluteMonthly: null
          relativeMonthly: null
        }
        durationHours: 4
        utcOffset: '+00:00'
        startDate: '2024-10-01'
        startTime: '00:00'
      }
    }
    managedIdentities: {
      userAssignedResourcesIds: [
        identity.outputs.resourceId
      ]
    }

    monitoringWorkspaceId: logAnalytics.outputs.resourceId

    diagnosticSettings: [
      {
        name: 'customSetting'
        logCategoriesAndGroups: [
          {
            category: 'kube-apiserver'
          }
          {
            category: 'kube-controller-manager'
          }
          {
            category: 'kube-scheduler'
          }
          {
            category: 'cluster-autoscaler'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]

    fluxExtension: {
      configurationSettings: {
        'helm-controller.enabled': 'true'
        'source-controller.enabled': 'true'
        'kustomize-controller.enabled': 'true'
        'notification-controller.enabled': 'true'
        'image-automation-controller.enabled': 'false'
        'image-reflector-controller.enabled': 'false'
      }
      configurations: [
        {
          namespace: 'flux-system'
          scope: 'cluster'
          gitRepository: {
            repositoryRef: {
              branch: 'main'
            }
            sshKnownHosts: ''
            syncIntervalInSeconds: 300
            timeoutInSeconds: 180
            url: 'https://github.com/mspnp/aks-baseline'
          }
        }
      ]
    }
  }
}
module pool1 './aks_agent_pool.bicep' = {
  name: '${configuration.name}-cluster-pool1'
  params: {
    AksName: managedCluster.outputs.name
    PoolName: 'poolz1'
    agentVMSize: vmSize
    agentCount: 1
    agentCountMax: 3
    availabilityZones: [
      '1'
    ]
    nodeTaints: ['app=cluster:NoSchedule']
    nodeLabels: {
      app: 'cluster'
    }
  }
}

module pool2 './aks_agent_pool.bicep' = {
  name: '${configuration.name}-cluster-pool2'
  params: {
    AksName: managedCluster.outputs.name
    PoolName: 'poolz2'
    agentVMSize: vmSize
    agentCount: 1
    agentCountMax: 3
    availabilityZones: [
      '2'
    ]
    nodeTaints: ['app=cluster:NoSchedule']
    nodeLabels: {
      app: 'cluster'
    }
  }
}

module pool3 './aks_agent_pool.bicep' = {
  name: '${configuration.name}-cluster-pool3'
  params: {
    AksName: managedCluster.outputs.name
    PoolName: 'poolz3'
    agentVMSize: vmSize
    agentCount: 1
    agentCountMax: 3
    availabilityZones: [
      '3'
    ]
    nodeTaints: ['app=cluster:NoSchedule']
    nodeLabels: {
      app: 'cluster'
    }
  }
}

var federatedIdentityCredentials = [
  {
    name: 'federated-ns_default'
    subject: 'system:serviceaccount:default:workload-identity-sa'
  }
]

@batchSize(1)
module federatedCredentials './federated_identity.bicep' = [for (cred, index) in federatedIdentityCredentials: {
  name: '${configuration.name}-${cred.name}'
  params: {
    name: cred.name
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: managedCluster.outputs.oidcIssuerUrl
    userAssignedIdentityName: identity.outputs.name
    subject: cred.subject
  }
  dependsOn: [
    managedCluster
  ]
}]

module appRoleAssignments './app_assignments.bicep' = {
  name: '${configuration.name}-user-managed-identity-rbac'
  params: {
    identityprincipalId: identity.outputs.principalId
    kvName: keyvault.outputs.name
  }
  dependsOn: [
    federatedCredentials
  ]
}



//--------------Config Map---------------
// SecretProviderClass --> tenantId, clientId, keyvaultName
// ServiceAccount --> tenantId, clientId
// AzureAppConfigurationProvider --> tenantId, clientId, configEndpoint, keyvaultUri, keyvaultName
var configMaps = {
  appConfigTemplate: '''
values.yaml: |
  serviceAccount:
    create: false
    name: "workload-identity-sa"
  azure:
    tenantId: {0}
    clientId: {1}
    configEndpoint: {2}
    keyvaultUri: {3}
    keyvaultName: {4}
  '''
}

module appConfigMap './aks-config-map/main.bicep' = {
  name: '${configuration.name}-cluster-appconfig-configmap'
  params: {
    aksName: managedCluster.outputs.name
    location: location
    name: 'config-map-values'
    namespace: 'default'
    
    // Order of items matters here.
    fileData: [
      format(configMaps.appConfigTemplate, 
             subscription().tenantId, 
             identity.outputs.clientId,
             configurationStore.outputs.endpoint,
             keyvault.outputs.uri,
             keyvault.outputs.name)
    ]
  }
}

module helmAppConfigProvider 'aks-run-command/main.bicep' = {
  name: '${configuration.name}-helm-appconfig-provider'
  params: {
    aksName: managedCluster.outputs.name
    location: location
    initialScriptDelay: '130s'

    commands: [
      'helm install azureappconfiguration.kubernetesprovider oci://mcr.microsoft.com/azure-app-configuration/helmchart/kubernetes-provider --namespace azappconfig-system --create-namespace'
    ]
  }
}
