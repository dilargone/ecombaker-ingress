# 🔧 Fixing Kubeconfig Secret Error

## The Error You're Seeing

```
error loading config file: couldn't get version/kind; 
json parse error: json: cannot unmarshal string into Go value
```

## What This Means

The `KUBE_CONFIG_DEV` secret in GitHub is **not properly formatted**. The workflow expects a **base64-encoded kubeconfig**, but something is wrong with how it's stored.

## Common Causes

### 1. **Secret is NOT base64 encoded** (Most Common)
You pasted the raw kubeconfig YAML instead of base64

### 2. **Secret is double-encoded**
You base64-encoded an already base64-encoded string

### 3. **Secret has extra characters**
Newlines, spaces, or wrapping in the base64 string

## How to Fix

### Quick Fix: Re-create the Secret Properly

Run this script to generate the correct format:

```bash
cd ecombaker-ingress-repo
./scripts/setup-github-secret.sh
```

This will:
1. Export your kubeconfig
2. Encode it properly to base64
3. Save to `/tmp/kubeconfig-{ENV}-base64.txt`
4. Copy to clipboard (macOS)

### Manual Fix: Step-by-Step

#### Step 1: Get your kubeconfig

```bash
# View your kubeconfig
cat ~/.kube/config

# Or export specific context
kubectl config view --context=dev-context --minify --flatten > /tmp/dev-kubeconfig.yaml
```

#### Step 2: Encode to base64 CORRECTLY

**On macOS:**
```bash
cat /tmp/dev-kubeconfig.yaml | base64 | tr -d '\n' > /tmp/dev-base64.txt
```

**On Linux:**
```bash
cat /tmp/dev-kubeconfig.yaml | base64 -w 0 > /tmp/dev-base64.txt
```

**⚠️ Important**: The `-w 0` or `tr -d '\n'` removes line breaks!

#### Step 3: Verify the encoding

```bash
# Test decode
cat /tmp/dev-base64.txt | base64 -d

# Should show valid YAML like:
# apiVersion: v1
# clusters:
# - cluster:
#     server: https://...
```

#### Step 4: Update GitHub Secret

1. Go to: https://github.com/dilargone/ecombaker-ingress/settings/secrets/actions
2. Click on `KUBE_CONFIG_DEV`
3. Click **Update**
4. Paste the content from `/tmp/dev-base64.txt`
5. Click **Update secret**

## Verification Checklist

Before updating the secret, verify:

### ✅ Your base64 string should:
- [ ] Be a **single long line** (no newlines)
- [ ] Start with something like: `YXBpVmVyc2lvbjogdjE...`
- [ ] Be much longer than the original YAML (base64 is ~33% larger)
- [ ] Decode back to valid YAML when you test it

### ❌ Your base64 string should NOT:
- [ ] Have multiple lines
- [ ] Look exactly like the YAML (means it's not encoded)
- [ ] Be shorter than the original (means something is wrong)
- [ ] Have spaces or newlines in the middle

## Test Your Secret Locally

Before adding to GitHub, test locally:

```bash
# 1. Create test file
echo "YOUR_BASE64_STRING_HERE" > /tmp/test-secret.txt

# 2. Decode it
cat /tmp/test-secret.txt | base64 -d > /tmp/test-kubeconfig.yaml

# 3. Test with kubectl
KUBECONFIG=/tmp/test-kubeconfig.yaml kubectl cluster-info

# If this works, your secret is correct! ✅
# If it fails, re-encode it properly
```

## Common Issues

### Issue 1: "invalid character" error
**Cause**: Secret contains raw YAML, not base64  
**Fix**: Encode the YAML with `cat kubeconfig.yaml | base64 | tr -d '\n'`

### Issue 2: "couldn't get version/kind" error (your current error)
**Cause**: Secret is malformed or has extra characters  
**Fix**: Re-encode from scratch, ensure no newlines in base64

### Issue 3: "Unauthorized" or "Forbidden" error
**Cause**: Kubeconfig is valid but credentials are wrong/expired  
**Fix**: Get fresh kubeconfig from your cluster

### Issue 4: "connection refused" error
**Cause**: Cluster URL is wrong or cluster is not accessible  
**Fix**: Verify cluster endpoint in kubeconfig

## Updated Workflow

I've updated the workflow to:
1. **Manually decode** the base64 secret
2. **Verify connection** before deploying
3. **Show better error messages**

The new workflow steps:
```yaml
- name: Configure kubectl
  run: |
    mkdir -p ~/.kube
    echo "${{ secrets.KUBE_CONFIG_DEV }}" | base64 -d > ~/.kube/config
    chmod 600 ~/.kube/config
    
- name: Verify cluster connection
  run: |
    kubectl cluster-info
    kubectl get nodes
```

## Quick Commands Reference

### Generate base64 secret (macOS)
```bash
cat ~/.kube/config | base64 | tr -d '\n' | pbcopy
```

### Generate base64 secret (Linux)
```bash
cat ~/.kube/config | base64 -w 0
```

### Test decode
```bash
echo "YOUR_BASE64" | base64 -d
```

### Extract specific cluster context
```bash
kubectl config view --context=my-context --minify --flatten
```

## What to Do Next

1. **Re-generate the base64 secret properly**:
   ```bash
   ./scripts/setup-github-secret.sh
   ```

2. **Update the GitHub secret**:
   - Go to repository secrets
   - Update `KUBE_CONFIG_DEV` with new value
   - Ensure it's the **base64-encoded** version

3. **Re-run the workflow**:
   - Go to Actions tab
   - Re-run the failed job
   - Check the new "Verify cluster connection" step

## Example of Correct Format

### ❌ WRONG (raw YAML in secret):
```yaml
apiVersion: v1
clusters:
- cluster:
    server: https://...
```

### ✅ CORRECT (base64 encoded):
```
YXBpVmVyc2lvbjogdjEKY2x1c3RlcnM6Ci0gY2x1c3RlcjoKICAgIHNlcnZlcjogaHR0cHM6Ly...
(one long line, no breaks)
```

## Still Having Issues?

If you continue to see errors:

1. **Check the workflow logs** - Look for the "Configure kubectl" step
2. **Verify your kubeconfig locally** - Test with `kubectl cluster-info`
3. **Check cluster access** - Ensure your cluster is accessible from internet
4. **Check credentials** - Ensure tokens/certs are not expired

---

**Quick TL;DR:**

```bash
# 1. Generate proper base64
cat ~/.kube/config | base64 | tr -d '\n' > /tmp/secret.txt

# 2. Update GitHub secret with content from /tmp/secret.txt

# 3. Re-run workflow

# Done! ✅
```
