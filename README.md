# Cluster PaaS

Playground project for running a managed Kubernetes cluster with production grade software.

1. Elastic Cluster Kubernetes Service (EKS)
2. Azure Container Native PostgreSQL (CNPG)
3. Redis Cluster

```bash
azd auth login

# Prepare Environment
azd init -e dev # This if first environment

# Provisioning
azd provision

# Cleanup
azd down --force --purge
```