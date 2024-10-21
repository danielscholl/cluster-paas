targetScope = 'resourceGroup'
metadata name = 'Managed Kubernetes.'
metadata description = 'This instance deploys a managed Kubernetes cluster.'


@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('The object ID of the user to assign the cluster admin role to.')
param userObjectId string

@description('Deploy Sample')
param stampTest bool = false



@description('Number of Elastic Instances')
param elasticInstances int = 1


@allowed([
  '8.15.3'
  '8.14.3'
  '7.17.24'
  '7.16.3'
])
param elasticVersion string = '8.15.3'

@description('Date Stamp - Used for sentinel in configuration store.')
param dateStamp string = utcNow()


var stampElastic = elasticInstances > 0 ? true : false

@description('Enable PaaS pool')
var enablePaasPool = false

@description('Load Service Mesh')
var enableMesh = false

@description('Internal Configuration Object')
var configuration = {
  name: 'main'
  displayName: 'Main Resources'
  logs: {
    sku: 'PerGB2018'
    retention: 30
  }
  vault: {
    sku: 'standard'
  }
  appconfig: {
    sku: 'Standard'
  }
  storage: {
    sku: 'Standard_LRS'
    tier: 'Hot'
  }
  registry: {
    sku: 'Standard'
  }
  cluster: {
    sku: 'Automatic'
    tier: 'Standard'
    vmSize: 'Standard_DS3_v2'
  }
}

@description('Unique ID for the resource group')
var rg_unique_id = '${replace(configuration.name, '-', '')}${uniqueString(resourceGroup().id, configuration.name)}'



/////////////////////////////////////////////////////////////////////
//  Identity Resources                                             //
/////////////////////////////////////////////////////////////////////
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



/////////////////////////////////////////////////////////////////////
//  Monitoring Resources                                           //
/////////////////////////////////////////////////////////////////////
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



/////////////////////////////////////////////////////////////////////
//  Cluster Resources                                              //
/////////////////////////////////////////////////////////////////////
// AVM doesn't support things like AKS Automatic SKU, so we use a custom module.
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

    skuTier: configuration.cluster.tier
    skuName: configuration.cluster.sku

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

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Azure Kubernetes Service RBAC Cluster Admin'
        principalId: userObjectId
        principalType: 'User'
      }
      {
        roleDefinitionIdOrName: 'Azure Kubernetes Service RBAC Cluster Admin'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    // These are all the things that are required for the Automatic SKU
    networkPlugin: 'azure'
    networkPluginMode: 'overlay'
    publicNetworkAccess: 'Enabled'
    outboundType: 'managedNATGateway'
    enableKeyvaultSecretsProvider: true
    enableSecretRotation: true
    enableImageCleaner: true
    imageCleanerIntervalHours: 168
    vpaAddon: true
    kedaAddon: true
    enableOidcIssuerProfile: true
    enableWorkloadIdentity: true
    azurePolicyEnabled: true
    omsAgentEnabled: true
    enableRBAC: true
    aadProfileManaged: true
    enablePrivateCluster: false
    disableLocalAccounts: true
    costAnalysisEnabled: true
    enableStorageProfileDiskCSIDriver: true
    enableStorageProfileFileCSIDriver: true
    enableStorageProfileSnapshotController: true
    enableStorageProfileBlobCSIDriver: true    
    webApplicationRoutingEnabled: true
    enableNodeAutoProvisioning: true
    aksServicePrincipalProfile: {
      clientId: 'msi'
    }
    managedIdentities: {
      systemAssigned: true  
    }
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
    primaryAgentPoolProfile: [
      {
        name: 'systempool'
        mode: 'System'
        vmSize: configuration.cluster.vmSize
        count: 1
        securityProfile: {
          sshAccess: 'Disabled'
        }
      }
    ]

    // Additional Agent Pool Configurations
    agentPools: concat([
      // Default User Pool has no taints or labels
      {
        name: 'defaultpool'
        mode: 'User'
        vmSize: configuration.cluster.vmSize
        count: 1
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
      }
    ], enablePaasPool ? [
      {
        name: 'paaspool'
        mode: 'User'
        vmSize: configuration.cluster.vmSize
        count: 1
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: ['app=cluster-paas:NoSchedule']
        nodeLabels: {
          app: 'cluster-paas'
        }
      }
    ] : [])
    
    // These are things that are optional items for this solution.
    enableAzureDefender: true
    enableContainerInsights: true
    monitoringWorkspaceId: logAnalytics.outputs.resourceId
    enableAzureMonitorProfileMetrics: true

    // Additional Add On Configurations
    istioServiceMeshEnabled: enableMesh ? true : false
    istioIngressGatewayEnabled: enableMesh ? true : false
    istioIngressGatewayType: enableMesh ? 'External' : null

  }
}

// Policy Assignments
module assignments './aks_policy.bicep' = {
  name: '${configuration.name}-policy-assignment'
  params: {
    clusterName: managedCluster.outputs.name
  }
  dependsOn: [
    managedCluster
  ]
}

// Retrieve the NAT Public IP
module natClusterIP './nat_public_ip.bicep' = {
  name: '${configuration.name}-nat-public-ip'
  params: {
    publicIpResourceId: managedCluster.outputs.outboundIpResourceId
  }
}

//  Federated Credentials
@description('Federated Identities for Namespaces')
var federatedIdentityCredentials = [
  {
    name: 'federated-ns_default'
    subject: 'system:serviceaccount:default:workload-identity-sa'
  }
  {
    name: 'federated-ns_elastic'
    subject: 'system:serviceaccount:elastic:workload-identity-sa'
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



/////////////////////////////////////////////////////////////////////
//  Image Resources                                             //
/////////////////////////////////////////////////////////////////////
module registry 'br/public:avm/res/container-registry/registry:0.5.1' = {
  name: '${configuration.name}-registry'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id  
    location: location
    acrSku: configuration.registry.sku

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

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'AcrPull'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'AcrPull'
        principalId: managedCluster.outputs.kubeletIdentityObjectId
        principalType: 'ServicePrincipal'
      }
    ]

    // Non-required parameters
    acrAdminUserEnabled: false
    azureADAuthenticationAsArmPolicyStatus: 'disabled'
  }
  
}



/////////////////////////////////////////////////////////////////////
//  Configuration Resources                                        //
/////////////////////////////////////////////////////////////////////
@description('App Configuration Values for configmap-services')
var configmapServices = [
  {
    name: 'sentinel'
    value: dateStamp
    label: 'common'
  }
  {
    name: 'tenant_id'
    value: subscription().tenantId
    contentType: 'text/plain'
    label: 'configmap-services'
  }
  {
    name: 'azure_msi_client_id'
    value: identity.outputs.clientId
    contentType: 'text/plain'
    label: 'configmap-services'
  }
  {
    name: 'keyvault_uri'
    value: keyvault.outputs.uri
    contentType: 'text/plain'
    label: 'configmap-services'
  }
  {
    name: 'elastic-instances'
    value: string(elasticInstances)
    contentType: 'text/plain'
    label: 'elastic-search'
  }
  {
    name: 'elastic-version'
    value: elasticVersion
    contentType: 'text/plain'
    label: 'elastic-search'
  }
]

// AVM doesn't have a nice way to create the values in the store, so we use a custom module.
module configurationStore './app-configuration/main.bicep' = {
  name: '${configuration.name}-appconfig'
  params: {
    // Required parameters
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id    
    location: location
    sku: configuration.appconfig.sku

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

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'App Configuration Data Reader'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    enablePurgeProtection: false
    disableLocalAuth: true

    // Add Configuration
    keyValues: concat(union(configmapServices, []))
  }
  dependsOn: [
    managedCluster
  ]
}

//  Vault Resources
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
  {
    secretName: 'elastic-username'
    secretValue: 'elastic'
  }
  {
    secretName: 'elastic-password'
    secretValue: substring(uniqueString(resourceGroup().id, userObjectId, location, 'saltpass'), 0, 13)
  }
  {
    secretName: 'elastic-key'
    secretValue: substring(uniqueString(resourceGroup().id, userObjectId, location, 'saltkey'), 0, 13)
  }
]

module keyvault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: '${configuration.name}-keyvault'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    sku: configuration.vault.sku
    
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
    
    // Configure RBAC
    enableRbacAuthorization: true
    roleAssignments: [{
      roleDefinitionIdOrName: 'Key Vault Secrets User'
      principalId: identity.outputs.principalId
      principalType: 'ServicePrincipal'
    }]

    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: natClusterIP.outputs.ipAddress
        }
      ]
    }

    // Configure Secrets
    secrets: [
      for secret in vaultSecrets: {
        name: secret.secretName
        value: secret.secretValue
      }
    ]
  }
  dependsOn: [
    managedCluster
    natClusterIP
  ]
}



/////////////////////////////////////////////////////////////////////
//  App Configuration Provider                                     //
/////////////////////////////////////////////////////////////////////
// AKS has an extension for App Configuration but installing with Helm for now.
module appConfigProviderExtension './app_configuration_provider.bicep' = {
  name: '${configuration.name}-appconfig-provider'
  params: {
    clusterName: managedCluster.outputs.name
  }
  dependsOn: [
    managedCluster
  ]
}



/////////////////////////////////////////////////////////////////////
//  Observability Resources                                        //
/////////////////////////////////////////////////////////////////////
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
  dependsOn: [
    managedCluster
  ]
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
  dependsOn: [
    prometheus
  ]
}



/////////////////////////////////////////////////////////////////////
//  Software Resources                                             //
/////////////////////////////////////////////////////////////////////
module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: '${configuration.name}-storage'
  params: {
    name: length(rg_unique_id) > 24 ? substring(rg_unique_id, 0, 24) : rg_unique_id
    location: location
    skuName: configuration.storage.sku
    accessTier: configuration.storage.tier
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

    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionIdOrName: 'Storage File Data SMB Share Contributor'
        principalId: identity.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]

    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled'

    networkAcls: {
      defaultAction: 'Allow'
    }

    managedIdentities: {
      userAssignedResourceIds: [
        identity.outputs.resourceId
      ]
    }

    blobServices: {
      containers: [
        {
          name: 'gitops'
        }
      ]
    }
  }
}

module gitOpsUpload './software-upload/main.bicep' = {
  name: '${configuration.name}-storage-gitops-upload'
  params: {
    storageAccountName: storageAccount.outputs.name
    location: location
    useExistingManagedIdentity: true
    managedIdentityName: identity.outputs.name
    existingManagedIdentitySubId: subscription().subscriptionId
    existingManagedIdentityResourceGroupName:resourceGroup().name
  }
  dependsOn: [
    storageAccount
    identity
  ]
}

module flux 'br/public:avm/res/kubernetes-configuration/extension:0.3.4' = {
  name: '${configuration.name}-gitops'
  params: {
    // Required parameters
    clusterName: managedCluster.outputs.name
    location: location
    extensionType: 'microsoft.flux'
    name: 'flux'
    
    releaseNamespace: 'flux-system'
    releaseTrain: 'Stable'
    // Non-required parameters
    configurationSettings: {
      'multiTenancy.enforce': 'false'
      'helm-controller.enabled': 'true'
      'source-controller.enabled': 'true'
      'kustomize-controller.enabled': 'true'
      'notification-controller.enabled': 'true'
      'image-automation-controller.enabled': 'false'
      'image-reflector-controller.enabled': 'false'
    }
    fluxConfigurations: [
      {
        namespace: 'flux-system'
        name: 'flux-system'
        scope: 'cluster'
        suspend: false
        gitRepository: {
          repositoryRef: {
            branch: 'main'
          }
          sshKnownHosts: ''
          syncIntervalInSeconds: 300
          timeoutInSeconds: 300
          url: 'https://github.com/danielscholl/cluster-paas'
        }
        kustomizations: {
          global: {
            path: './software/global'
            dependsOn: []
            syncIntervalInSeconds: 300
            timeoutInSeconds: 300
            validation: 'none'
            prune: true
          }
          ...(stampTest ? {
            stamptest: {
              path: './software/stamp-test'
              dependsOn: ['global']
              syncIntervalInSeconds: 300
              timeoutInSeconds: 300
              validation: 'none'
              prune: true
            }
          } : {})
          ...(stampElastic ? {
            stampelastic: {
              path: './software/stamp-elastic'
              dependsOn: ['global']
              syncIntervalInSeconds: 300
              timeoutInSeconds: 300
              validation: 'none'
              prune: true
            }
          } : {})
        }
      }
    ]
  }
  dependsOn: [
    managedCluster
    gitOpsUpload
    keyvault
    registry
  ]
}

module storageAcl './storage_acl.bicep' = {
  name: '${configuration.name}-storage-acl'
  params: {
    storageName: storageAccount.outputs.name
    location: location
    skuName: configuration.storage.sku
    natClusterIP: natClusterIP.outputs.ipAddress
  }
  dependsOn: [
    gitOpsUpload
  ]
}

//--------------Config Map---------------
// SecretProviderClass --> tenantId, clientId, keyvaultName
// ServiceAccount --> tenantId, clientId
// AzureAppConfigurationProvider --> tenantId, clientId, configEndpoint, keyvaultUri, keyvaultName
@description('Default Config Map to get things needed for secrets and configmaps')
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

// Create the Initial Config Map for the App Configuration Provider
module appConfigMap './aks-config-map/main.bicep' = {
  name: '${configuration.name}-cluster-appconfig-configmap'
  params: {
    aksName: managedCluster.outputs.name
    location: location
    name: 'system-values'
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

    newOrExistingManagedIdentity: 'existing'
    managedIdentityName: identity.outputs.name
    existingManagedIdentitySubId: subscription().subscriptionId
    existingManagedIdentityResourceGroupName:resourceGroup().name
  }
  dependsOn: [
    managedCluster
    flux
    appConfigProviderExtension
  ]
}

