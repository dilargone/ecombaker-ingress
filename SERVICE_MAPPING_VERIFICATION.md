# Service Name Verification - Ingress to Service Mapping

## ✅ Verification Complete - All Services Correctly Mapped

This document verifies that ingress resources point to the correct service names in the store-pilot repository.

---

## Service Name Mapping

### Dev Environment

| Ingress Path | Service Name (Ingress) | Service Name (store-pilot) | Status |
|-------------|------------------------|---------------------------|--------|
| `/api` | `pilot-service-dev` | `pilot-service-dev` | ✅ MATCH |
| `/app` | `pilot-frontend-service-dev` | _(frontend not yet created)_ | ⚠️ PENDING |
| `/actuator` | `pilot-service-dev` | `pilot-service-dev` | ✅ MATCH |
| `/swagger-ui` | `pilot-service-dev` | `pilot-service-dev` | ✅ MATCH |

**File Locations:**
- Ingress: `ecombaker-ingress-repo/overlays/dev/ingress-patch.yaml`
- Service: `store-pilot/k8s/dev/service.yaml`

---

### QA Environment

| Ingress Path | Service Name (Ingress) | Service Name (store-pilot) | Status |
|-------------|------------------------|---------------------------|--------|
| `/api` | `pilot-service-qa` | `pilot-service-qa` | ✅ MATCH |
| `/app` | `pilot-frontend-service-qa` | _(frontend not yet created)_ | ⚠️ PENDING |
| `/actuator` | `pilot-service-qa` | `pilot-service-qa` | ✅ MATCH |
| `/swagger-ui` | `pilot-service-qa` | `pilot-service-qa` | ✅ MATCH |

**File Locations:**
- Ingress: `ecombaker-ingress-repo/overlays/qa/ingress-patch.yaml`
- Service: `store-pilot/k8s/qa/service.yaml`

---

### Prod Environment

| Ingress Path | Service Name (Ingress) | Service Name (store-pilot) | Status |
|-------------|------------------------|---------------------------|--------|
| `/api` | `pilot-service` | `pilot-service` | ✅ MATCH |
| `/app` | `pilot-frontend-service` | _(frontend not yet created)_ | ⚠️ PENDING |
| `/actuator` | `pilot-service` | `pilot-service` | ✅ MATCH |
| `/swagger-ui` | `pilot-service` | `pilot-service` | ✅ MATCH |

**File Locations:**
- Ingress: `ecombaker-ingress-repo/base/ingress.yaml`
- Service: `store-pilot/k8s/prod/service.yaml`

---

## Service Configuration Details

### Backend Services (Spring Boot)

#### Dev
```yaml
# store-pilot/k8s/dev/service.yaml
metadata:
  name: pilot-service-dev
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
```

#### QA
```yaml
# store-pilot/k8s/qa/service.yaml
metadata:
  name: pilot-service-qa
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
```

#### Prod
```yaml
# store-pilot/k8s/prod/service.yaml
metadata:
  name: pilot-service
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
```

---

## Ingress Configuration Details

### Dev Ingress
```yaml
# ecombaker-ingress-repo/overlays/dev/ingress-patch.yaml
spec:
  rules:
  - host: "*.dev.ecombaker.com"
    http:
      paths:
      - path: /api
        backend:
          service:
            name: pilot-service-dev  # ✅ Matches store-pilot
            port:
              number: 8080
```

### QA Ingress
```yaml
# ecombaker-ingress-repo/overlays/qa/ingress-patch.yaml
spec:
  rules:
  - host: "*.qa.ecombaker.com"
    http:
      paths:
      - path: /api
        backend:
          service:
            name: pilot-service-qa  # ✅ Matches store-pilot
            port:
              number: 8080
```

### Prod Ingress
```yaml
# ecombaker-ingress-repo/base/ingress.yaml
spec:
  rules:
  - host: "*.ecombaker.com"
    http:
      paths:
      - path: /api
        backend:
          service:
            name: pilot-service  # ✅ Matches store-pilot
            port:
              number: 8080
```

---

## Namespace Configuration

Services and Ingress must be in the **same namespace** for routing to work.

### Current Namespace Strategy

| Environment | Namespace | Services | Ingress | Status |
|------------|-----------|----------|---------|--------|
| **Dev** | `ecombaker-dev-namespace` | ✅ Deployed here | ✅ Deployed here | ✅ SAME |
| **QA** | `ecombaker-qa-namespace` | ✅ Deployed here | ✅ Deployed here | ✅ SAME |
| **Prod** | `ecombaker-prod-namespace` | ✅ Deployed here | ✅ Deployed here | ✅ SAME |

**Why this matters:**
- Ingress can only route to services in the **same namespace**
- Cross-namespace routing requires additional configuration (ExternalName services)

---

## Traffic Flow Verification

### Example: QA Environment

```
User Request: http://store1.qa.ecombaker.com/api/products
   ↓
DNS Resolution: 138.197.254.45 (or new ingress IP)
   ↓
DigitalOcean LoadBalancer
   ↓
NGINX Ingress Controller (ingress-nginx namespace)
   ↓
Ingress Rule: *.qa.ecombaker.com → /api → pilot-service-qa:8080
   ↓
Service: pilot-service-qa (ecombaker-qa-namespace)
   ↓
Pod Selector: app=springboot-app, environment=qa
   ↓
Spring Boot Application Pod
```

---

## Port Configuration

All configurations use correct ports:

| Service | Ingress Port | Service Port | Container Port | Status |
|---------|-------------|--------------|----------------|--------|
| Backend (Dev) | 8080 | 8080 | 8080 | ✅ MATCH |
| Backend (QA) | 8080 | 8080 | 8080 | ✅ MATCH |
| Backend (Prod) | 8080 | 8080 | 8080 | ✅ MATCH |

**Port Flow:**
```
Ingress → Service:8080 → Pod:8080
```

---

## Frontend Services (Pending)

The ingress references frontend services that don't exist yet:

| Environment | Ingress Reference | Actual Service | Status |
|------------|------------------|----------------|--------|
| Dev | `pilot-frontend-service-dev` | ❌ Not created | ⚠️ 404 errors on `/app` |
| QA | `pilot-frontend-service-qa` | ❌ Not created | ⚠️ 404 errors on `/app` |
| Prod | `pilot-frontend-service` | ❌ Not created | ⚠️ 404 errors on `/app` |

**Impact:**
- Requests to `/app` path will fail with 503 (Service Unavailable)
- Backend API routes (`/api`, `/actuator`, `/swagger-ui`) work fine

**To Fix:**
Create frontend service in store-pilot repository:

```yaml
# store-pilot/k8s/qa/frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: pilot-frontend-service-qa
spec:
  type: ClusterIP
  selector:
    app: frontend-app
    environment: qa
  ports:
    - port: 80
      targetPort: 80
```

---

## Validation Commands

### Check if service exists in cluster
```bash
# QA example
kubectl get svc pilot-service-qa -n ecombaker-qa-namespace
```

### Check if ingress points to correct service
```bash
# QA example
kubectl get ingress ecombaker-ingress -n ecombaker-qa-namespace -o yaml | grep -A 5 "name: pilot-service-qa"
```

### Check service endpoints (actual pods)
```bash
# QA example
kubectl get endpoints pilot-service-qa -n ecombaker-qa-namespace
```

### Test ingress routing
```bash
# QA example (from inside cluster or with port-forward)
curl -H "Host: store1.qa.ecombaker.com" http://<ingress-ip>/actuator/health
```

---

## Common Issues and Fixes

### Issue 1: 503 Service Unavailable
**Symptoms:** Ingress returns 503 for `/api` requests

**Possible Causes:**
1. Service name mismatch between ingress and actual service
2. Service not deployed in the same namespace as ingress
3. No pods matching the service selector

**Check:**
```bash
# Verify service exists
kubectl get svc pilot-service-qa -n ecombaker-qa-namespace

# Verify service has endpoints
kubectl get endpoints pilot-service-qa -n ecombaker-qa-namespace

# Should show pod IPs - if empty, no pods are matched
```

**Fix:**
- Ensure service name in ingress matches service name in k8s/
- Deploy pods with correct labels (`app=springboot-app, environment=qa`)

---

### Issue 2: 404 Not Found
**Symptoms:** Ingress routes correctly but app returns 404

**Possible Causes:**
1. Application doesn't have endpoint at that path
2. Context path mismatch (e.g., app expects `/api` prefix)

**Check:**
```bash
# Test directly to pod (bypass ingress)
kubectl exec -it <pod-name> -n ecombaker-qa-namespace -- curl localhost:8080/api/products
```

---

### Issue 3: Connection Refused
**Symptoms:** Ingress can't connect to service

**Possible Causes:**
1. Service port doesn't match pod's containerPort
2. Pod not listening on expected port
3. Service selector doesn't match pod labels

**Check:**
```bash
# Check service configuration
kubectl describe svc pilot-service-qa -n ecombaker-qa-namespace

# Check pod labels
kubectl get pods -n ecombaker-qa-namespace --show-labels

# Check if service selector matches any pods
kubectl get pods -n ecombaker-qa-namespace -l app=springboot-app,environment=qa
```

---

## Summary

### ✅ What's Working
- All backend service names match between ingress and store-pilot
- All namespaces are consistent
- All port configurations are correct
- Service types are all ClusterIP (no LoadBalancers)

### ⚠️ What's Missing
- Frontend services (`pilot-frontend-service-*`) not yet created
- `/app` path will return 503 until frontend services are deployed

### 🎯 Recommendation
The current configuration is correct for **backend API traffic**. No changes needed unless:
1. You want to deploy frontend services (create them in store-pilot/k8s/)
2. You want to remove `/app` paths from ingress (if no frontend planned)

---

**Last Verified:** December 25, 2025  
**Verified By:** Automated service name mapping check  
**Status:** ✅ All backend services correctly mapped
