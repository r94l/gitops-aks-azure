# AKS GitOps Platform — Terraform + ArgoCD on Azure

A production-ready Infrastructure-as-Code project that provisions an **Azure Kubernetes Service (AKS)** cluster and sets up a full **GitOps workflow** using **ArgoCD**, all managed through **Terraform**. The project deploys a three-tier web application (React frontend, Node.js backend, PostgreSQL database) across three isolated environments — dev, test, and prod.

---

## 🧠 What This Project Does

This project automates the end-to-end provisioning of a cloud-native deployment platform on Azure. Instead of manually configuring Kubernetes clusters or deploying applications by hand, everything — from infrastructure to application delivery — is defined as code and driven by Git.

Key capabilities:
- **Terraform provisions the AKS cluster** including auto-scaling node pools, Azure AD RBAC integration, Azure CNI networking, and Azure Key Vault for secrets management
- **ArgoCD is installed and configured by Terraform** via the Helm provider — no manual Helm commands needed
- **GitOps-driven deployments** mean ArgoCD watches a Git repository and automatically syncs your application manifests to the cluster
- **Three fully isolated environments** (dev, test, prod) with progressive resource scaling and separate Terraform state files
- **Azure Key Vault CSI integration** allows Kubernetes pods to securely consume secrets without hardcoding credentials

---

## 🏗️ Architecture Overview

```
.
├── dev/                    # Development environment
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── outputs.tf
│   ├── backend.tf
│   ├── backend.tf.example
│   ├── kubernetes-resources.tf
│   ├── argocd-app-manifest.yaml
│   ├── deploy-argocd-app.sh
│   └── validate-deployment.sh
├── test/                   # Test/staging environment
│   └── (same structure as dev/)
├── prod/                   # Production environment
│   └── (same structure as dev/)
└── README.md
```

### Core Components

| Component | Tool/Service | Purpose |
|---|---|---|
| Infrastructure | Terraform | Provisions AKS, Key Vault, networking, identities |
| Container Orchestration | Azure Kubernetes Service (AKS) | Hosts all workloads |
| GitOps Engine | ArgoCD | Syncs manifests from Git to cluster |
| Secrets Management | Azure Key Vault + CSI Driver | Injects secrets securely into pods |
| State Backend | Azure Blob Storage | Remote Terraform state per environment |
| Auth | Azure AD + Service Principal | Cluster and Terraform authentication |

### Application Stack (3-Tier)

| Tier | Technology | Port |
|---|---|---|
| Frontend | React + Express proxy | 3000 |
| Backend | Node.js REST API | 8080 |
| Database | PostgreSQL 15 with PVC | 5432 |

---

## 🌍 Multi-Environment Configuration

Each environment is independently configurable with its own `.tfvars`, backend state, and resource sizing:

| Environment | Region | VM Size | Default Nodes | Auto-Scale Range | Disk |
|---|---|---|---|---|---|
| **Dev** | East US | Standard_D2s_v3 | 2 | 1–5 | 30 GB |
| **Test** | East US 2 | Standard_D4s_v3 | 3 | 2–8 | 50 GB |
| **Prod** | West US 2 | Standard_D8s_v3 | 5 | 3–10 | 100 GB |

---

## ✅ Prerequisites

### Required Tools

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Optional Tools (for manual cluster operations)

```bash
# kubectl — for inspecting and debugging cluster resources
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm — only needed for manual chart operations; Terraform handles ArgoCD installation
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

> **Note:** Terraform handles ArgoCD installation, Kubernetes resource creation, and GitOps app deployment automatically. kubectl and Helm are only needed for troubleshooting and verification.

---

## 🚀 Deployment Guide

### Step 1: Set Up Your GitOps Repository (Do This First)

ArgoCD needs access to your manifest files before the infrastructure is deployed. Skipping this step will cause ArgoCD application sync to fail.

```bash
# Create a new GitHub repo (e.g., gitops-configs), then clone it
git clone https://github.com/YOUR_USERNAME/gitops-configs.git
cd gitops-configs

# Copy the application manifests into your repo
# Your repo should contain a 3tire-configs/ folder with:
# namespace.yaml, frontend.yaml, backend.yaml, postgres.yaml,
# postgres-pvc.yaml, frontend-config.yaml, backend-config.yaml,
# postgres-config.yaml, kustomization.yaml, argocd-application.yaml

# In argocd-application.yaml, update the repoURL to point to your repo:
# repoURL: https://github.com/YOUR_USERNAME/gitops-configs.git

git add .
git commit -m "Initial GitOps manifests"
git push origin main
```

### Step 2: Azure Authentication

```bash
az login
az account set --subscription "your-subscription-id"

# Create a service principal for Terraform
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
az ad sp create-for-rbac \
  --name "terraform-aks-gitops" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth

# Export the credentials as environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

### Step 3: Update Terraform Variables

In each environment folder, open `terraform.tfvars` and update:

```bash
# In dev/terraform.tfvars, test/terraform.tfvars, and prod/terraform.tfvars:
app_repo_url = "https://github.com/YOUR_USERNAME/gitops-configs.git"
```

### Step 4: (Optional) Configure Remote State Backend

```bash
# Create an Azure Storage Account for Terraform state
az group create --name "rg-terraform-state" --location "East US"

STORAGE_ACCOUNT_NAME="tfstate$(date +%s)"
az storage account create \
  --resource-group "rg-terraform-state" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --sku "Standard_LRS" \
  --encryption-services blob

az storage container create \
  --name "tfstate" \
  --account-name "$STORAGE_ACCOUNT_NAME"

# In each environment folder, copy backend.tf.example to backend.tf and fill in the values
cp backend.tf.example backend.tf
```

### Step 5: Deploy an Environment

```bash
# Example: deploying the dev environment
cd dev/
terraform init
terraform plan
terraform apply -auto-approve
```

Terraform will automatically provision: the AKS cluster, Azure Key Vault, ArgoCD via Helm, Kubernetes namespaces and RBAC, and the ArgoCD application pointing to your GitOps repo.

Repeat for `test/` and `prod/` as needed.

### Step 6: Connect kubectl to the Cluster

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --admin \
  --overwrite-existing

kubectl get nodes
```

---

## 🔐 Key Vault Integration

After deployment, update your GitOps repository's `3tire-configs/key-vault-secrets.yaml` with the actual Key Vault values:

```bash
# Get required values
KEY_VAULT_NAME=$(terraform output -raw key_vault_name)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Use the Key Vault Secrets Provider identity (NOT the kubelet identity)
KV_CLIENT_ID=$(az aks show \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --query "addonProfiles.azureKeyvaultSecretsProvider.identity.clientId" -o tsv)
```

> ⚠️ **Common mistake:** Do not use the kubelet identity (`identityProfile.kubeletidentity.clientId`) for the `SecretProviderClass`. Always use the Key Vault Secrets Provider identity shown above — using the wrong one causes 403 Forbidden errors.

Update the placeholders in `key-vault-secrets.yaml`:

```yaml
userAssignedIdentityID: "<KV_CLIENT_ID>"   # Key Vault Secrets Provider client ID
keyvaultName: "<KEY_VAULT_NAME>"
tenantId: "<TENANT_ID>"
```

Commit and push — ArgoCD will auto-sync the changes to your cluster.

---

## 🌐 Accessing ArgoCD

```bash
# Get the ArgoCD LoadBalancer IP
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get the admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD URL: http://$ARGOCD_IP"
echo "Username: admin | Password: $ARGOCD_PASSWORD"
```

If the LoadBalancer IP isn't available yet, use port forwarding:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Access at: http://localhost:8080
```

---

## 🖥️ Accessing the Application

### Quick Access (Port Forward)

```bash
kubectl port-forward svc/frontend -n 3tirewebapp-dev 3000:3000
# Open: http://localhost:3000
```

### Production-like Access (Ingress)

The frontend manifest includes a pre-configured NGINX Ingress resource with host `3tirewebapp-dev.local`.

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Get Ingress IP and add to /etc/hosts
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$INGRESS_IP 3tirewebapp-dev.local" | sudo tee -a /etc/hosts

# Access at: http://3tirewebapp-dev.local
```

### Access Method Summary

| Method | Best For | URL |
|---|---|---|
| Port Forward | Dev/quick testing | `http://localhost:3000` |
| NGINX Ingress | Staging/production-like | `http://3tirewebapp-dev.local` |
| LoadBalancer | External demo access | `http://<EXTERNAL-IP>:3000` |

---

## ✅ Verification

```bash
# Cluster health
kubectl get nodes
kubectl cluster-info

# ArgoCD status
kubectl get pods -n argocd
kubectl get applications -n argocd

# Application pods
kubectl get pods -n 3tirewebapp-dev

# Key Vault integration
kubectl get secretproviderclass -n 3tirewebapp-dev
kubectl get secret postgres-credentials-from-kv -n 3tirewebapp-dev
```

A healthy deployment shows all nodes in `Ready` state, all ArgoCD pods `Running`, and applications with `Synced` + `Healthy` status.

---

## 🔧 Troubleshooting

**kubectl can't connect to cluster**
```bash
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --admin --overwrite-existing
```

**ArgoCD UI not loading**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

**Terraform apply fails**
```bash
az account show           # verify Azure auth
terraform init -reconfigure
terraform plan
```

**ArgoCD app out of sync**
```bash
kubectl patch application <app-name> -n argocd --type merge \
  --patch '{"operation":{"sync":{"syncStrategy":{"force":true}}}}'
```

**Pod stuck in ContainerCreating (Key Vault)**
```bash
kubectl describe pod -l app=postgres -n 3tirewebapp-dev
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

---

## 🧹 Cleanup

```bash
# Remove all ArgoCD applications
kubectl delete applications --all -n argocd

# Destroy infrastructure
terraform destroy -auto-approve

# Remove kubectl context
kubectl config delete-context <cluster-context>
```

---

## 🛠️ Tech Stack

`Terraform` · `Azure Kubernetes Service (AKS)` · `ArgoCD` · `Azure Key Vault` · `Azure CNI` · `Helm` · `React` · `Node.js` · `PostgreSQL` · `NGINX Ingress` · `Kubernetes CSI Secrets Store`
