# Cluster PaaS

Playground project for running a production grade solution using AKS Automatic with a production grade software deployment.


| Security              | Networking                        | AutoScaling        | Observability                |
|-----------------------|-----------------------------------|--------------------|------------------------------|
| Azure Linux           | Azure CNI Overlay                 | Node Autoprovision | Managed Prometheus           |
| Automatic Upgrades    | App Routing add-on                | KEDA add-on        | Container Insights           |
| Azure RBAC            | NAT Gateway                       | VPA add-on         | Azure Managed Grafana        | 
| Local access disabled |                                   |                    | Container Insights workbooks |
| SSH access disabled   |                                   |                    | Azure Policy Dashboards      |
| Workload Identity     |                                   |                    | Prometheus Alert Rules       |
| Image Cleaner         |                                   |                    | Azure Action Groups          |
| NRG Lockdown          |                                   |                    |                              |
| Deployment Safeguards |                                   |                    |                              |
| Azure Policy          |                                   |                    |                              |
| Azure Key Vault       |                                   |                    |                              |
| App Configuration     |                                   |                    |                              |
| Azure Gitops          |                                   |                    |                              |
| Azure Service Mesh    |                                   |                    |                              |


1. Elastic Cluster Kubernetes Service (EKS)
2. Azure Container Native PostgreSQL (CNPG)
3. Redis Cluster


### Register the feature flags

To use AKS Automatic in preview, you must register feature flags for other required features. Register the following flags using the [az feature register](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-register) command.

```bash
az feature register --namespace Microsoft.ContainerService --name EnableAPIServerVnetIntegrationPreview
az feature register --namespace Microsoft.ContainerService --name NRGLockdownPreview
az feature register --namespace Microsoft.ContainerService --name SafeguardsPreview
az feature register --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview
az feature register --namespace Microsoft.ContainerService --name DisableSSHPreview
az feature register --namespace Microsoft.ContainerService --name AutomaticSKUPreview
```

Verify the registration status by using the [az feature show](https://learn.microsoft.com/en-us/cli/azure/feature?view=azure-cli-latest#az-feature-show) command. It takes a few minutes for the status to show *Registered*:

```bash
az feature show --namespace Microsoft.ContainerService --name AutomaticSKUPreview
```

When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register](https://learn.microsoft.com/en-us/cli/azure/provider?view=azure-cli-latest#az-provider-register) command:


### Provision the environment

```bash
az provider register --namespace Microsoft.ContainerService
```

```bash
## Enable Experimental Features
azd config set alpha.deployment.stacks on

## Authenticate
azd auth login

# Initialize Environment
azd init -e dev 

# Provisioning
azd provision

```





