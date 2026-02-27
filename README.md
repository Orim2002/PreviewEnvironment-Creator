# Preview Environment Creator

GitHub Actions CI/CD pipeline that automatically creates and destroys live preview environments for every Pull Request. On PR open/update it builds a Docker image, deploys it to Kubernetes, and comments the live URL on the PR. On PR close it tears the environment down.

---

## How It Works

### On PR Opened or Updated

```
PR opened/synchronized
        ↓
Build Docker image (tagged with short git SHA)
        ↓
Push to Docker Hub
        ↓
Login to Azure via OIDC (no client secret)
        ↓
Fetch AKS kubeconfig via azure/aks-set-context
        ↓
Apply PreviewEnvironment custom resource to Kubernetes
        ↓
Poll until namespace preview-pr-{N} is Active
        ↓
Wait for deployment rollout to complete
        ↓
Post PR comment with live URL
```

### On PR Closed

```
PR closed
    ↓
Login to Azure via OIDC
    ↓
Delete PreviewEnvironment CR
    ↓
Operator tears down namespace + all resources
```

---

## Files

| File | Description |
|------|-------------|
| `.github/workflows/workflow-ex.yml` | Main GitHub Actions workflow |
| `cr.yaml` | Example `PreviewEnvironment` custom resource |
| `Dockerfile` | Sample app Dockerfile for testing |

---

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `AZURE_CLIENT_ID` | Service principal client ID (for OIDC login) |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AKS_RESOURCE_GROUP` | Resource group containing the AKS cluster |
| `AKS_CLUSTER_NAME` | Name of the AKS cluster |

> No `KUBECONFIG` secret needed — kubeconfig is fetched dynamically via OIDC.

---

## Workflow Steps

```yaml
# Triggered on PR open/update
- Checkout code
- Set image tag to short git SHA (first 7 chars)
- Login to Docker Hub
- Build and push Docker image
- Login to Azure with OIDC (azure/login@v2, no client_secret)
- Fetch AKS kubeconfig (azure/aks-set-context@v3)
- Apply PreviewEnvironment CR to the cluster
- Poll for namespace to become Active (up to 90s)
- Wait for deployment rollout (kubectl rollout status, timeout 120s)
- Post PR comment with preview URL

# Triggered on PR close
- Login to Azure with OIDC
- Fetch AKS kubeconfig
- Delete PreviewEnvironment CR (operator handles cleanup)
```

---

## Preview URL Format

```
https://pr-{PR_NUMBER}.preview.orimatest.com
```

Example: PR #42 → `https://pr-42.preview.orimatest.com`

---

## Architecture Note

The workflow is intentionally simple — it only applies a single YAML manifest. All the complexity of creating Deployments, Services, Ingresses, NetworkPolicies, and namespaces lives inside the operator. This means:

- Changing how environments are provisioned only requires updating the operator, not every workflow
- The CI pipeline has no knowledge of Kubernetes internals
- Adding new fields to the environment spec is a one-line change in the workflow
- No static credentials — Azure authentication uses OIDC federation
