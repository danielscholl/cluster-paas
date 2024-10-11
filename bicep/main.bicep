targetScope = 'resourceGroup'
metadata name = 'Managed Kubernetes.'
metadata description = 'This instance deploys a managed Kubernetes cluster.'


@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Server Size. - Standard_DS2_v2')
param vmSize string

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



// //*****************************************************************//
// //  Storage Resources                                             //
// //*****************************************************************//
// module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
//   name: '${configuration.name}-storage'
//   params: {
//     name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
//     location: location

//     // Assign Tags
//     tags: {
//       layer: configuration.displayName
//       id: rg_unique_id
//     }

//     diagnosticSettings: [
//       {
//         workspaceResourceId: logAnalytics.outputs.resourceId
//       }
//     ]

//     allowBlobPublicAccess: false
//     allowSharedKeyAccess: true
//     publicNetworkAccess: 'Disabled'

//     networkAcls: {
//       bypass: 'AzureServices'
//       defaultAction: 'Allow'
//     }

//     managedIdentities: {
//       userAssignedResourceIds: [
//         identity.outputs.resourceId
//       ]
//     }

//     blobServices: {
//       containers: [
//         {
//           name: 'gitops'
//         }
//       ]
//     }
//   }
// }

// module roleAssignments './app_assignments.bicep' = {
//   name: '${configuration.name}-role-assignments'
//   params: {
//     identityprincipalId: identity.outputs.principalId
//     storageName: storageAccount.outputs.name
//   }
// }



//*****************************************************************//
//  Vault Resources                                           //
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



//*****************************************************************//
//  Configuration Resources                                        //
//*****************************************************************//

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




// module manifestDagShareUpload './script-storage-upload/main.bicep' = {
//   name: '${configuration.name}-storage-gitops-upload'
//   params: {
//     storageAccountName: storageAccount.outputs.name
//     location: location
//     useExistingManagedIdentity: true
//     managedIdentityName: identity.outputs.name
//     existingManagedIdentitySubId: subscription().subscriptionId
//     existingManagedIdentityResourceGroupName:resourceGroup().name
//   }
// }



//*****************************************************************//
//  Cluster Resources                                             //
//*****************************************************************//

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

// AVM doesn't support istioServiceMesh yet, so we need to use a modified module.
module managedCluster './managed-cluster/main.bicep' = {
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
    enableAzureMonitorProfileMetrics: true

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

    istioServiceMeshEnabled: true
    istioIngressGatewayEnabled: true
    istioIngressGatewayType: 'External'

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

    agentPools: [
      {
        availabilityZones: [
          '1'
        ]
        count: 1
        enableAutoScaling: true
        maxCount: 3
        maxPods: 30
        minCount: 1
        minPods: 2
        mode: 'User'
        name: 'poolz1'
        osDiskSizeGB: 128
        osType: 'Linux'
        scaleSetEvictionPolicy: 'Delete'
        scaleSetPriority: 'Regular'
        type: 'VirtualMachineScaleSets'
        vmSize: vmSize
        nodeTaints: ['app=cluster:NoSchedule']
        nodeLabels: {
          app: 'cluster'
        }
      }
      {
        name: 'poolz2'
        availabilityZones: [
          '2'
        ]
        count: 1
        enableAutoScaling: true
        maxCount: 3
        maxPods: 30
        minCount: 1
        minPods: 2
        mode: 'User'
        osDiskSizeGB: 128
        osType: 'Linux'
        scaleSetEvictionPolicy: 'Delete'
        scaleSetPriority: 'Regular'
        type: 'VirtualMachineScaleSets'
        vmSize: vmSize
        nodeTaints: ['app=cluster:NoSchedule']
        nodeLabels: {
          app: 'cluster'
        }
      }
      {
        name: 'poolz3'
        availabilityZones: [
          '3'
        ]
        count: 1
        enableAutoScaling: true
        maxCount: 3
        maxPods: 30
        minCount: 1
        minPods: 2
        mode: 'User'
        osDiskSizeGB: 128
        osType: 'Linux'
        scaleSetEvictionPolicy: 'Delete'
        scaleSetPriority: 'Regular'
        type: 'VirtualMachineScaleSets'
        vmSize: vmSize
        nodeTaints: ['app=cluster:NoSchedule']
        nodeLabels: {
          app: 'cluster'
        }
      }
    ]
  }
}



//*****************************************************************//
//  Federated Credentials                                           //
//*****************************************************************//
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



//*****************************************************************//
//  App Configuration Provider - Extension                         //
//*****************************************************************//
module appConfigProvider './app_configuration_provider.bicep' = {
  name: '${configuration.name}-appconfig-provider'
  params: {
    clusterName: managedCluster.outputs.name
  }
  dependsOn: [
    managedCluster
  ]
}



//*****************************************************************//
//  Managed Prometheus & Grafana                                   //
//*****************************************************************//
module prometheus 'aks_prometheus.bicep' = {
  name: '${configuration.name}-managed-prometheus'
  params: {
    // Basic Details
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    publicNetworkAccess: 'Enabled'    
    clusterName: managedCluster.outputs.name
    actionGroupId: ''
  }
}

module grafana 'aks_grafana.bicep' = {
  name: '${configuration.name}-managed-grafana'

  params: {
    // Basic Details
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    tags: {
      layer: configuration.displayName
      id: rg_unique_id
    }

    skuName: 'Standard'
    apiKey: 'Enabled'
    autoGeneratedDomainNameLabelScope: 'TenantReuse'
    deterministicOutboundIP: 'Disabled'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
    prometheusName: prometheus.outputs.name
  }
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

// module appConfigMap './aks-config-map/main.bicep' = {
//   name: '${configuration.name}-cluster-appconfig-configmap'
//   params: {
//     aksName: managedCluster.outputs.name
//     location: location
//     name: 'config-map-values'
//     namespace: 'default'
    
//     // Order of items matters here.
//     fileData: [
//       format(configMaps.appConfigTemplate, 
//              subscription().tenantId, 
//              identity.outputs.clientId,
//              configurationStore.outputs.endpoint,
//              keyvault.outputs.uri,
//              keyvault.outputs.name)
//     ]

//     newOrExistingManagedIdentity: 'existing'
//     managedIdentityName: identity.outputs.name
//     existingManagedIdentitySubId: subscription().subscriptionId
//     existingManagedIdentityResourceGroupName:resourceGroup().name
//   }
//   dependsOn: [
//     managedCluster
//   ]
// }

