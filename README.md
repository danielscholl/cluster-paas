# Cluster PaaS

Playground project for running a managed Kubernetes cluster with production grade software.

1. Elastic Cluster Kubernetes Service (EKS)
2. Azure Container Native PostgreSQL (CNPG)
3. Redis Cluster

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


## Notes

This playground project is to explore the use of Azure Kubernetes Service Automatic (AKS-Automatic) with a focus on production grade software.


| Security              | Networking                        | AutoScaling | Observability |
|-----------------------|-----------------------------------|-------------|---------------|
| Azure Linux           | __POD__ Azure CNI Overlay         | Node Autoprovision | Managed Prometheus |
| Automatic Upgrades    | __INGRESS__ App Routing add-on    | KEDA add-on        | Container Insights |
| Azure RBAC enabled    | __EGRESS__ NAT Gateway            | VPA add-on         |Azure Managed Grafana |
| Local access disabled |                                   |                    | Container Insights workbooks |
| SSH access disabled   |                                   |                    | Azure Policy Dashboards |
| Workload Identity  addon   |                              |                    | Prometheus Alert Rules |
| Image Cleaner addon   |                                   |                    | Azure Action Groups |
| NRG Lockdown          |                                   |                    |  |
| Deployment Safeguards |                                   |                    |  |
| Azure Policy addon    |                                   |                    |  |
| Azure Key Vault addon |                                   |                    |  |


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

```bash
az provider register --namespace Microsoft.ContainerService
```