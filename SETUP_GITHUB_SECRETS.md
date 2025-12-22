# 🔐 Setting Up GitHub Secrets for Kubernetes Deployment

## The Problem

Your GitHub Actions workflow needs access to your Kubernetes cluster(s) to deploy the ingress configuration. This access is provided through **kubeconfig** files stored as **GitHub Secrets**.

## What You Need to Configure

Add these 3 secrets to your GitHub repository:

| Secret Name | Description | Required For |
|------------|-------------|--------------|
| `KUBE_CONFIG_DEV` | Dev cluster kubeconfig | Development deployments |
| `KUBE_CONFIG_QA` | QA cluster kubeconfig | QA deployments |
| `KUBE_CONFIG_PROD` | Prod cluster kubeconfig | Production deployments |

## Step-by-Step Setup

### Step 1: Get Your Kubeconfig File

Your kubeconfig file is usually located at `~/.kube/config`

```bash
# View your kubeconfig
cat ~/.kube/config

# If you have multiple clusters, you'll see contexts for each
kubectl config get-contexts
```

**Example kubeconfig structure:**
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...
    server: https://your-cluster.example.com
  name: dev-cluster
contexts:
- context:
    cluster: dev-cluster
    user: dev-user
  name: dev-context
current-context: dev-context
kind: Config
users:
- name: dev-user
  user:
    token: eyJhbGciOiJSUzI1NiIs...
```

### Step 2: Extract Environment-Specific Kubeconfig

If you have separate clusters for dev/qa/prod, you need to extract each one:

#### Option A: Separate Cluster Files (Recommended)

If you have separate kubeconfig files:
```bash
# For dev cluster
cat ~/.kube/dev-config

# For qa cluster
cat ~/.kube/qa-config

# For prod cluster
cat ~/.kube/prod-config
```

#### Option B: Extract from Single Kubeconfig

If all clusters are in one file, extract each context:

```bash
# Export dev context
kubectl config view --context=dev-context --minify --flatten > /tmp/dev-kubeconfig.yaml

# Export qa context
kubectl config view --context=qa-context --minify --flatten > /tmp/qa-kubeconfig.yaml

# Export prod context
kubectl config view --context=prod-context --minify --flatten > /tmp/prod-kubeconfig.yaml
```

### Step 3: Encode Kubeconfig to Base64

GitHub Actions expects the kubeconfig as a **base64-encoded string**:

```bash
# For Dev
cat ~/.kube/dev-config | base64

# Or if you extracted it:
cat /tmp/dev-kubeconfig.yaml | base64

# For QA
cat ~/.kube/qa-config | base64

# For Prod
cat ~/.kube/prod-config | base64
```

**⚠️ Important**: Copy the entire base64 output (it will be long!)

### Step 4: Add Secrets to GitHub

#### Via GitHub Web Interface:

1. Go to your GitHub repository: `https://github.com/dilargone/ecombaker-ingress`
2. Click **Settings** (top right)
3. In left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**

**Add each secret:**

| Name | Value |
|------|-------|
| `KUBE_CONFIG_DEV` | Paste the base64 output for dev cluster |
| `KUBE_CONFIG_QA` | Paste the base64 output for qa cluster |
| `KUBE_CONFIG_PROD` | Paste the base64 output for prod cluster |

#### Via GitHub CLI (Alternative):

```bash
# Install GitHub CLI if not already installed
brew install gh

# Authenticate
gh auth login

# Add secrets
gh secret set KUBE_CONFIG_DEV < /tmp/dev-kubeconfig-base64.txt --repo dilargone/ecombaker-ingress
gh secret set KUBE_CONFIG_QA < /tmp/qa-kubeconfig-base64.txt --repo dilargone/ecombaker-ingress
gh secret set KUBE_CONFIG_PROD < /tmp/prod-kubeconfig-base64.txt --repo dilargone/ecombaker-ingress
```

### Step 5: Verify Secrets Are Set

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. You should see:
   ```
   KUBE_CONFIG_DEV     Updated X minutes ago
   KUBE_CONFIG_QA      Updated X minutes ago
   KUBE_CONFIG_PROD    Updated X minutes ago
   ```

## How the Workflow Uses These Secrets

When the GitHub Actions workflow runs, it:

1. **Reads the secret**: `${{ secrets.KUBE_CONFIG_DEV }}`
2. **Decodes from base64**: Back to original kubeconfig format
3. **Writes to file**: `~/.kube/config`
4. **Uses kubectl**: Can now connect to your cluster

**Example from deploy.yml:**
```yaml
- name: Set up kubeconfig
  run: |
    mkdir -p ~/.kube
    echo "${{ secrets.KUBE_CONFIG_DEV }}" | base64 -d > ~/.kube/config
    chmod 600 ~/.kube/config
```

## Quick Reference Commands

### Get kubeconfig for specific context
```bash
kubectl config view --context=<context-name> --minify --flatten
```

### Convert to base64 (macOS/Linux)
```bash
cat kubeconfig.yaml | base64
```

### Convert to base64 (single line - no wrapping)
```bash
cat kubeconfig.yaml | base64 | tr -d '\n'
```

### Test if kubeconfig works
```bash
KUBECONFIG=/tmp/dev-kubeconfig.yaml kubectl get nodes
```

### Decode base64 to verify
```bash
echo "LS0tLS1CRUdJTi..." | base64 -d
```

## Security Best Practices

### ✅ DO:
- Use **service accounts** with limited permissions
- Set **expiration** on tokens/credentials
- Use **separate kubeconfig** for each environment
- **Rotate secrets** regularly
- Use **environment protection rules** in GitHub

### ❌ DON'T:
- Share kubeconfig files in Git
- Use admin/root credentials
- Use same kubeconfig for all environments
- Store unencoded kubeconfig in secrets
- Give GitHub Actions more permissions than needed

## Creating Service Account (Recommended Approach)

Instead of using your personal kubeconfig, create a dedicated service account:

```bash
# Create service account for GitHub Actions
kubectl create serviceaccount github-actions -n default

# Create role with necessary permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ingress-deployer
  namespace: default
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
EOF

# Bind role to service account
kubectl create rolebinding github-actions-binding \
  --role=ingress-deployer \
  --serviceaccount=default:github-actions \
  -n default

# Get service account token
kubectl create token github-actions --duration=87600h
# Copy this token
```

Then create kubeconfig using this service account token instead of your personal credentials.

## Troubleshooting

### Error: "The connection to the server localhost:8080 was refused"
**Solution**: Kubeconfig secret is not set or incorrectly formatted

### Error: "error: You must be logged in to the server (Unauthorized)"
**Solution**: Token/credentials in kubeconfig are expired or invalid

### Error: "base64: invalid input"
**Solution**: The secret wasn't encoded properly. Re-encode with `base64`

### Workflow runs but shows "Error from server (Forbidden)"
**Solution**: Service account doesn't have sufficient permissions. Add RBAC rules.

## Validation Workflow

After setting up secrets, test with this command:

```bash
# This will validate manifests without needing cluster access
kustomize build overlays/dev/ | kubectl apply --dry-run=client -f -
```

## What's Next?

After adding secrets:

1. ✅ Push a commit to `main` branch
2. ✅ GitHub Actions will auto-deploy to dev
3. ✅ Manual deployment to qa/prod via Actions tab
4. ✅ Check workflow logs to verify success

## Quick Setup Script

Save this as `setup-github-secrets.sh`:

```bash
#!/bin/bash

echo "🔐 GitHub Secrets Setup for Kubernetes"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured"
    exit 1
fi

# Get current context
CONTEXT=$(kubectl config current-context)
echo "Current context: $CONTEXT"
echo ""

# Export and encode
echo "Exporting kubeconfig..."
kubectl config view --minify --flatten > /tmp/kubeconfig.yaml

echo "Encoding to base64..."
cat /tmp/kubeconfig.yaml | base64 > /tmp/kubeconfig-base64.txt

echo ""
echo "✅ Base64-encoded kubeconfig saved to: /tmp/kubeconfig-base64.txt"
echo ""
echo "Copy the contents and add to GitHub:"
echo "1. Go to: https://github.com/dilargone/ecombaker-ingress/settings/secrets/actions"
echo "2. Click 'New repository secret'"
echo "3. Name: KUBE_CONFIG_DEV (or QA/PROD)"
echo "4. Value: Paste the base64 content"
echo ""

# Clean up
rm /tmp/kubeconfig.yaml
```

Run it:
```bash
chmod +x setup-github-secrets.sh
./setup-github-secrets.sh
```

---

**Need help?** Check the workflow logs in GitHub Actions to see specific error messages.
