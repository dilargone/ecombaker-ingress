# ⚡ Quick Fix: GitHub Actions Kubernetes Connection Error

## The Error You're Seeing

```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
Error: Process completed with exit code 1.
```

## Why This Happens

GitHub Actions can't connect to your Kubernetes cluster because the **kubeconfig secrets are not set up** in GitHub.

## Quick Fix (3 Steps)

### Step 1: Generate Base64 Kubeconfig

Run this helper script:

```bash
cd ecombaker-ingress-repo
./scripts/setup-github-secret.sh
```

This will:
1. Ask which environment (DEV/QA/PROD)
2. Export your kubeconfig
3. Encode it to base64
4. Save to `/tmp/kubeconfig-{ENV}-base64.txt`
5. (macOS) Offer to copy to clipboard

### Step 2: Add Secret to GitHub

1. Go to: **https://github.com/dilargone/ecombaker-ingress/settings/secrets/actions**

2. Click: **New repository secret**

3. Add each secret:

| Secret Name | Get From |
|------------|----------|
| `KUBE_CONFIG_DEV` | Run script, select "1) Development" |
| `KUBE_CONFIG_QA` | Run script, select "2) QA" |
| `KUBE_CONFIG_PROD` | Run script, select "3) Production" |

4. Paste the base64 content from `/tmp/kubeconfig-{ENV}-base64.txt`

### Step 3: Re-run GitHub Action

1. Go to: **https://github.com/dilargone/ecombaker-ingress/actions**
2. Find the failed workflow run
3. Click **Re-run all jobs**

Or push a new commit:
```bash
git add .
git commit -m "Fix: Update workflow configuration"
git push
```

## What the Secrets Do

```
GitHub Actions Workflow
        ↓
Reads: ${{ secrets.KUBE_CONFIG_DEV }}
        ↓
Decodes: base64 -d
        ↓
Writes: ~/.kube/config
        ↓
kubectl can now connect to your cluster! ✅
```

## Manual Method (If Script Doesn't Work)

```bash
# 1. Export kubeconfig
kubectl config view --minify --flatten > /tmp/kubeconfig.yaml

# 2. Encode to base64 (macOS)
cat /tmp/kubeconfig.yaml | base64 | tr -d '\n' > /tmp/kubeconfig-base64.txt

# 3. Copy content
cat /tmp/kubeconfig-base64.txt

# 4. Paste in GitHub as KUBE_CONFIG_DEV (or QA/PROD)

# 5. Clean up
rm /tmp/kubeconfig.yaml /tmp/kubeconfig-base64.txt
```

## Verify Secrets Are Set

Go to: **Settings → Secrets and variables → Actions**

You should see:
```
KUBE_CONFIG_DEV     Updated X minutes ago
KUBE_CONFIG_QA      Updated X minutes ago  
KUBE_CONFIG_PROD    Updated X minutes ago
```

## Common Issues

### "I don't have a Kubernetes cluster yet"
**Solution**: You can skip the deployment jobs for now. The validation job will still run (it doesn't need cluster access after my fix).

### "I only have one cluster (dev)"
**Solution**: Just add `KUBE_CONFIG_DEV`. QA and prod workflows won't run until you add their secrets.

### "My kubeconfig has multiple contexts"
**Solution**: Run the script for each context, or extract manually:
```bash
kubectl config use-context dev-context
./scripts/setup-github-secret.sh  # Select DEV

kubectl config use-context qa-context
./scripts/setup-github-secret.sh  # Select QA
```

## Security Notes

- ⚠️ **Never commit kubeconfig** to Git
- ⚠️ **Delete temp files** after adding to GitHub
- ✅ **Use service accounts** with limited permissions (recommended)
- ✅ **Rotate secrets** regularly

## Alternative: Skip Deployment for Now

If you don't want to set up secrets yet, you can disable the deployment jobs:

1. Comment out the `deploy-dev`, `deploy-qa`, `deploy-prod` jobs in `.github/workflows/deploy.yml`
2. Only the `validate` job will run (doesn't need cluster access)

## Files Created to Help You

| File | Purpose |
|------|---------|
| `scripts/setup-github-secret.sh` | Interactive helper to generate base64 kubeconfig |
| `SETUP_GITHUB_SECRETS.md` | Complete detailed guide |
| This file | Quick reference |

## TL;DR

```bash
# 1. Run this:
./scripts/setup-github-secret.sh

# 2. Go here:
open https://github.com/dilargone/ecombaker-ingress/settings/secrets/actions

# 3. Add secret KUBE_CONFIG_DEV with the base64 content

# 4. Done! ✅
```

---

**Still stuck?** Check the detailed guide: `SETUP_GITHUB_SECRETS.md`
