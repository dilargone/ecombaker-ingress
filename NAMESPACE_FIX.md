# Namespace Configuration Fix

## Problem
When trying to deploy to a custom namespace via GitHub Actions, the deployment failed with:
```
error: the namespace from the provided object "default" does not match the namespace "ecombaker-qa-namespace". 
You must pass '--namespace=default' to perform this operation.
```

## Root Cause
The namespace was **hardcoded** in multiple places:
- `base/ingress.yaml` - had `namespace: default` in metadata
- `overlays/dev/kustomization.yaml` - had `namespace: default`
- `overlays/qa/kustomization.yaml` - had `namespace: default`
- `overlays/prod/kustomization.yaml` - had `namespace: default`

When you specify `-n custom-namespace` with kubectl, it conflicts with the hardcoded namespace in the manifest.

## Solution
Removed the hardcoded `namespace: default` from all files:

### Files Modified:
1. ✅ `base/ingress.yaml` - Removed `namespace: default` from metadata
2. ✅ `overlays/dev/kustomization.yaml` - Removed `namespace: default` field
3. ✅ `overlays/qa/kustomization.yaml` - Removed `namespace: default` field
4. ✅ `overlays/prod/kustomization.yaml` - Removed `namespace: default` field

### How It Works Now:
```bash
# Namespace is specified at deployment time
kubectl apply -k overlays/qa/ -n my-custom-namespace

# If no namespace specified, uses current context default
kubectl apply -k overlays/qa/
```

## GitHub Actions Usage

The workflow now correctly:
1. Creates the namespace if needed
2. Deploys to that namespace
3. Checks status in that namespace

### Example:
```yaml
workflow_dispatch:
  inputs:
    namespace: "ecombaker-qa-namespace"  # Custom namespace
    
# Deployment will:
- kubectl create namespace ecombaker-qa-namespace  # If not exists
- kubectl apply -k overlays/qa/ -n ecombaker-qa-namespace
- kubectl get ingress -n ecombaker-qa-namespace
```

## Testing Locally

```bash
# Test that namespace is not hardcoded
kubectl kustomize overlays/qa/ | grep "namespace:"
# Should return nothing (no hardcoded namespace)

# Deploy to custom namespace
kubectl create namespace test-namespace
kubectl apply -k overlays/qa/ -n test-namespace
kubectl get ingress -n test-namespace

# Clean up
kubectl delete ingress ecombaker-ingress -n test-namespace
kubectl delete namespace test-namespace
```

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
