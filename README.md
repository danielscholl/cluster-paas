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