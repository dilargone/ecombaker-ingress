# ⚠️ SERVICE NAME MISMATCH DETECTED

## The Problem

Your **ingress configuration** references service names that **don't match** what's defined in the `store-pilot` repository!

## Current Mismatch

### In Ingress (ecombaker-ingress-repo)
```yaml
# Dev ingress expects:
service:
  name: pilot-service-dev          ❌ DOES NOT EXIST
  port: 8080

service:
  name: pilot-frontend-service-dev ❌ DOES NOT EXIST
  port: 80
```

### In store-pilot k8s/dev/service.yaml
```yaml
# Actual service name:
metadata:
  name: springboot-app-service-dev  ✅ THIS EXISTS
spec:
  ports:
    - port: 80
      targetPort: 8080
```

## Complete Comparison Table

| Environment | Ingress Expects | Actual Service Name | Status |
|-------------|----------------|---------------------|--------|
| **DEV** | `pilot-service-dev` | `springboot-app-service-dev` | ❌ MISMATCH |
| **DEV** | `pilot-frontend-service-dev` | Not found | ❌ MISSING |
| **QA** | `pilot-service-qa` | `springboot-app-service-qa` | ❌ MISMATCH |
| **QA** | `pilot-frontend-service-qa` | Not found | ❌ MISSING |
| **PROD** | `pilot-service` | `springboot-app-service-prod` | ❌ MISMATCH |
| **PROD** | `pilot-frontend-service` | Not found | ❌ MISSING |

## Issues to Fix

### Issue 1: Backend Service Name Mismatch
**Problem**: Ingress looks for `pilot-service-*` but service is named `springboot-app-service-*`

### Issue 2: Port Mismatch
**Ingress expects**: Port `8080`  
**Service exposes**: Port `80` (forwards to targetPort `8080`)

### Issue 3: Frontend Service Missing
**Problem**: No frontend service defined in store-pilot k8s configs

### Issue 4: Service Type
**Current**: `LoadBalancer` (creates external IP)  
**Should be**: `ClusterIP` (internal only, ingress handles external access)

## Solution Options

### Option 1: Update Ingress to Match Existing Services (RECOMMENDED)
Change the ingress to use the actual service names.

### Option 2: Rename Services in store-pilot
Change service names in k8s YAML files to match ingress expectations.

### Option 3: Create Missing Frontend Service
Add frontend service definitions to store-pilot.

## Recommended Fix

I recommend **Option 1** because it's safer (only changes ingress, not deployed services).

### Changes Needed in Ingress:

**For Dev (`overlays/dev/ingress-patch.yaml`):**
```yaml
# Change from:
name: pilot-service-dev
port: 8080

# To:
name: springboot-app-service-dev
port: 80  # Service exposes port 80
```

**For QA (`overlays/qa/ingress-patch.yaml`):**
```yaml
# Change from:
name: pilot-service-qa
port: 8080

# To:
name: springboot-app-service-qa
port: 80
```

**For Prod (base `ingress.yaml`):**
```yaml
# Change from:
name: pilot-service
port: 8080

# To:
name: springboot-app-service-prod
port: 80
```

## What About Frontend Service?

You have two options:

### A. Remove Frontend Routes (if no separate frontend)
If your Spring Boot app serves both API and frontend:
```yaml
# Remove these sections from ingress:
- path: /app
  backend:
    service:
      name: pilot-frontend-service-dev  # DELETE THIS
```

### B. Create Frontend Service (if separate frontend exists)
Add to `store-pilot/k8s/dev/frontend-service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: pilot-frontend-service-dev
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

## Next Steps

1. **Decide**: Do you have a separate frontend service?
   - ❌ No → Remove frontend routes from ingress
   - ✅ Yes → Create frontend service definitions

2. **Fix ingress service names** to match actual services

3. **Change service type** from LoadBalancer to ClusterIP (since ingress handles external access)

4. **Update ports** to match service exposed ports

Would you like me to make these changes for you?
