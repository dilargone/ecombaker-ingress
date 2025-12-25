# Commands to Check Ingress Status

## Quick Health Check

### 1. Check if Ingress Exists
```bash
# Check in specific namespace
kubectl get ingress -n ecombaker-qa-namespace

# Check all namespaces
kubectl get ingress -A

# Get detailed output
kubectl get ingress ecombaker-ingress -n ecombaker-qa-namespace -o wide
```

### 2. Check Ingress Details
```bash
# Full description with events
kubectl describe ingress ecombaker-ingress -n ecombaker-qa-namespace

# View the YAML configuration
kubectl get ingress ecombaker-ingress -n ecombaker-qa-namespace -o yaml
```

### 3. Check NGINX Ingress Controller
```bash
# Check if controller pods are running
kubectl get pods -n ingress-nginx

# Check controller service and external IP
kubectl get svc -n ingress-nginx

# Get external IP specifically
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 4. Check Backend Services
```bash
# Check if backend services exist
kubectl get svc -n ecombaker-qa-namespace

# Specifically check your services
kubectl get svc pilot-service-qa -n ecombaker-qa-namespace
kubectl get svc pilot-frontend-service-qa -n ecombaker-qa-namespace
```

### 5. Check Ingress Controller Logs
```bash
# View recent logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Follow logs in real-time
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Filter for your ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep ecombaker
```

## Complete Health Check Script

```bash
#!/bin/bash

NAMESPACE="ecombaker-qa-namespace"
INGRESS_NAME="ecombaker-ingress"

echo "🔍 Checking Ingress Status..."
echo ""

# 1. Check namespace exists
echo "1️⃣ Checking namespace..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "✅ Namespace '$NAMESPACE' exists"
else
    echo "❌ Namespace '$NAMESPACE' not found"
    exit 1
fi
echo ""

# 2. Check ingress resource
echo "2️⃣ Checking ingress resource..."
if kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "✅ Ingress '$INGRESS_NAME' exists"
    kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o wide
else
    echo "❌ Ingress '$INGRESS_NAME' not found"
    exit 1
fi
echo ""

# 3. Check ingress controller
echo "3️⃣ Checking NGINX ingress controller..."
if kubectl get pods -n ingress-nginx &> /dev/null; then
    READY_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l | tr -d ' ')
    TOTAL_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers | wc -l | tr -d ' ')
    
    if [ "$READY_PODS" -gt 0 ]; then
        echo "✅ Ingress controller running ($READY_PODS/$TOTAL_PODS pods ready)"
    else
        echo "⚠️  Ingress controller pods not ready ($READY_PODS/$TOTAL_PODS)"
    fi
else
    echo "❌ Ingress controller not found (install with: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/do/deploy.yaml)"
fi
echo ""

# 4. Check external IP
echo "4️⃣ Checking external IP..."
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$EXTERNAL_IP" ]; then
    echo "✅ External IP: $EXTERNAL_IP"
else
    echo "⚠️  No external IP assigned yet (may take 2-3 minutes)"
fi
echo ""

# 5. Check backend services
echo "5️⃣ Checking backend services..."
kubectl get svc -n "$NAMESPACE" 2>/dev/null || echo "⚠️  No services found in namespace"
echo ""

# 6. Show ingress details
echo "6️⃣ Ingress configuration:"
kubectl describe ingress "$INGRESS_NAME" -n "$NAMESPACE" | grep -A 20 "Rules:"
echo ""

echo "✅ Health check complete!"
```

## Test Ingress Connectivity

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test health endpoint (if backend service exists)
curl -H "Host: store1.qa.ecombaker.com" \
     -H "X-Tenant-Domain: store1.qa.ecombaker.com" \
     http://$EXTERNAL_IP/actuator/health

# Test API endpoint
curl -H "Host: store1.qa.ecombaker.com" \
     http://$EXTERNAL_IP/api/

# Test with verbose output
curl -v -H "Host: store1.qa.ecombaker.com" \
     http://$EXTERNAL_IP/
```

## Watch Ingress in Real-Time

```bash
# Watch ingress status
watch -n 2 "kubectl get ingress ecombaker-ingress -n ecombaker-qa-namespace"

# Watch controller pods
watch -n 2 "kubectl get pods -n ingress-nginx"

# Watch all resources
watch -n 2 "kubectl get all -n ecombaker-qa-namespace"
```

## Troubleshooting Commands

```bash
# Check events in namespace
kubectl get events -n ecombaker-qa-namespace --sort-by='.lastTimestamp'

# Check ingress controller events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'

# Check if services are endpoints are ready
kubectl get endpoints -n ecombaker-qa-namespace

# Port-forward to test backend directly (bypass ingress)
kubectl port-forward -n ecombaker-qa-namespace svc/pilot-service-qa 8080:8080
# Then test: curl http://localhost:8080/actuator/health
```

## Quick Status One-Liner

```bash
# All-in-one status check
echo "Namespace:" && kubectl get ns ecombaker-qa-namespace && \
echo -e "\nIngress:" && kubectl get ingress -n ecombaker-qa-namespace && \
echo -e "\nServices:" && kubectl get svc -n ecombaker-qa-namespace && \
echo -e "\nController:" && kubectl get pods -n ingress-nginx && \
echo -e "\nExternal IP:" && kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Expected Output (Healthy State)

```
✅ Namespace: ecombaker-qa-namespace (Active)
✅ Ingress: ecombaker-ingress (nginx class, hosts: *.qa.ecombaker.com)
✅ Controller: ingress-nginx-controller pods Running (1/1 or more)
✅ External IP: X.X.X.X (DigitalOcean LoadBalancer IP)
✅ Backend Services: pilot-service-qa, pilot-frontend-service-qa (if deployed)
```

## What to Look For

### Ingress is Working When:
- ✅ `kubectl get ingress` shows your ingress with correct hosts
- ✅ `kubectl get svc -n ingress-nginx` shows EXTERNAL-IP (not `<pending>`)
- ✅ `kubectl get pods -n ingress-nginx` shows controller pods as `Running` and `Ready`
- ✅ Backend services exist and are running
- ✅ `curl` to external IP with Host header returns response (not 503)

### Common Issues:
- ❌ Ingress controller not installed → Install NGINX ingress controller
- ❌ External IP is `<pending>` → Wait 2-3 minutes for LoadBalancer provisioning
- ❌ Backend services 503 error → Services don't exist or pods not ready
- ❌ 404 error → Path routing issue or Host header mismatch
