# Namespace Configuration Fix

## Problem
When trying to deploy to a custom namespace via GitHub Actions, the deployment failed with:
```
error: the namespace from the provided object "default" does not match the namespace "ecombaker-qa-namespace". 
You must pass '--namespace=default' to perform this operation.
```

## Root Cause
The namespace was **hardcoded** in multiple kustomization files:
- `base/kustomization.yaml` - had `namespace: default`
- `base/ingress.yaml` - had `namespace: default` in metadata
- `overlays/dev/kustomization.yaml` - had `namespace: default`
- `overlays/qa/kustomization.yaml` - had `namespace: default`
- `overlays/prod/kustomization.yaml` - had `namespace: default`

When you specify `-n custom-namespace` with kubectl, it conflicts with the hardcoded namespace in the manifest.

## Solution
1. **Removed hardcoded namespaces** from all 5 files listed above
2. **Changed deployment approach** in GitHub Actions to properly override namespace:
   ```bash
   # OLD (doesn't properly override namespace)
   kubectl apply -k overlays/qa/ -n custom-namespace
   
   # NEW (builds manifest first, then applies with namespace)
   kubectl kustomize overlays/qa/ | kubectl apply -n custom-namespace -f -
   ```

### Files Modified:
1. ✅ `base/kustomization.yaml` - Removed `namespace: default` field
2. ✅ `base/ingress.yaml` - Removed `namespace: default` from metadata
3. ✅ `overlays/dev/kustomization.yaml` - Removed `namespace: default` field
4. ✅ `overlays/qa/kustomization.yaml` - Removed `namespace: default` field
5. ✅ `overlays/prod/kustomization.yaml` - Removed `namespace: default` field
6. ✅ `.github/workflows/deploy.yml` - Updated deployment commands to use pipe approach

### How It Works Now:
```bash
# Build manifest and apply to custom namespace
kubectl kustomize overlays/qa/ | kubectl apply -n my-custom-namespace -f -

# Build manifest and apply to default namespace
kubectl kustomize overlays/qa/ | kubectl apply -n default -f -
```

## GitHub Actions Usage

The workflow now correctly:
1. Creates the namespace if needed
2. Builds the manifest using `kubectl kustomize`
3. Pipes it to `kubectl apply` with namespace override
4. Checks status in that namespace

### Example:
```yaml
workflow_dispatch:
  inputs:
    namespace: "ecombaker-qa-namespace"  # Custom namespace
    
# Deployment will:
- kubectl create namespace ecombaker-qa-namespace  # If not exists
- kubectl kustomize overlays/qa/ | kubectl apply -n ecombaker-qa-namespace -f -
- kubectl get ingress -n ecombaker-qa-namespace
```

## Testing Locally

```bash
# Test that namespace is not hardcoded
kubectl kustomize overlays/qa/ | grep "namespace:"
# Should return nothing (no hardcoded namespace)

# Deploy to custom namespace
kubectl create namespace test-namespace
kubectl kustomize overlays/qa/ | kubectl apply -n test-namespace -f -
kubectl get ingress -n test-namespace

# Clean up
kubectl delete ingress ecombaker-ingress -n test-namespace
kubectl delete namespace test-namespace
```

## Why The Pipe Approach Works

The key difference:
- `kubectl apply -k PATH -n NAMESPACE` - Kustomize sets namespace, then kubectl tries to override (conflict!)
- `kubectl kustomize PATH | kubectl apply -n NAMESPACE -f -` - Manifest is built without namespace, then kubectl applies it to specified namespace (no conflict!)

## Important Notes

⚠️ **If you have an existing ingress in the `default` namespace**, it will stay there until you:
1. Delete it: `kubectl delete ingress ecombaker-ingress -n default`
2. Re-deploy to a new namespace via GitHub Actions

✅ **The fix is backward compatible**: 
- If you don't specify a namespace, it will use the current kubectl context's default namespace
- If you specify `-n namespace-name`, it will use that namespace
- GitHub Actions defaults to `default` namespace if not specified in the workflow input

## Future Deployments

All future deployments via GitHub Actions will respect the namespace input parameter and deploy to the correct namespace without conflicts.
