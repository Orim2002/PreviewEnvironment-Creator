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
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `KUBECONFIG` | Base64-encoded kubeconfig for the AKS cluster |

---

## Workflow Steps

```yaml
# Triggered on PR open/update
- Checkout code
- Set image tag to short git SHA (first 7 chars)
- Login to Docker Hub
- Build and push Docker image
- Configure kubectl with cluster kubeconfig
- Apply PreviewEnvironment CR to the cluster
- Poll for namespace to become Active (up to 90s)
- Wait for deployment rollout (kubectl rollout status, timeout 120s)
- Post PR comment with preview URL

# Triggered on PR close
- Configure kubectl
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

The workflow is intentionally simple — it only applies a single YAML manifest. All the complexity of creating Deployments, Services, Ingresses, and namespaces lives inside the operator. This means:

- Changing how environments are provisioned only requires updating the operator, not every workflow
- The CI pipeline has no knowledge of Kubernetes internals
- Adding new fields to the environment spec is a one-line change in the workflow
