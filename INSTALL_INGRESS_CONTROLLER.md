# NGINX Ingress Controller Management

## GitHub Action: Install/Uninstall NGINX Ingress Controller

### Workflow: `install-ingress-controller.yml`

This workflow allows you to install or uninstall the NGINX Ingress Controller (and its LoadBalancer) via GitHub Actions.

## Usage

### To Install NGINX Ingress Controller

1. Go to **Actions** → **Install NGINX Ingress Controller**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: dev / qa / prod
   - **Install NGINX Ingress Controller**: ✅ `true` (checked)
   - **Namespace**: `ingress-nginx` (default)
4. Click **Run workflow**

**What it does:**
- ✅ Checks if controller already installed
- ✅ Installs NGINX Ingress Controller for DigitalOcean
- ✅ Creates LoadBalancer service
- ✅ Waits for external IP assignment
- ✅ Displays LoadBalancer IP and next steps
- 💰 Cost: ~$12/month for the LoadBalancer

**Result:**
```
✅ NGINX Ingress Controller Installed!
🌐 LoadBalancer External IP: X.X.X.X
```

### To Uninstall NGINX Ingress Controller

1. Go to **Actions** → **Install NGINX Ingress Controller**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: dev / qa / prod
   - **Install NGINX Ingress Controller**: ❌ `false` (unchecked)
4. Click **Run workflow**

**What it does:**
- ⚠️  Backs up all ingress resources
- ⚠️  Shows LoadBalancer IP being released
- ❌ Deletes ingress-nginx namespace
- ❌ Deletes LoadBalancer
- 💰 Saves ~$12/month

## After Installation: Configure Your App

Once the ingress controller is installed with its LoadBalancer, you need to:

### 1. Update DNS
Point your domains to the new LoadBalancer IP:
```bash
*.qa.ecombaker.com    A    <LOADBALANCER_IP>
```

### 2. Change Application Service Type

Your application services need to change from `LoadBalancer` to `ClusterIP` so traffic goes through ingress:

**Current (Direct LoadBalancer):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: springboot-app-service-qa
spec:
  type: LoadBalancer  # ❌ Remove this
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: pilot
```

**New (Via Ingress):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: pilot-service-qa  # Match ingress backend name
spec:
  type: ClusterIP  # ✅ Change to ClusterIP
  ports:
    - port: 8080  # ✅ Use application port
      targetPort: 8080
  selector:
    app: pilot
```

### 3. Deploy Ingress Resources

```bash
# Via GitHub Actions
# Go to: Actions → Deploy Ingress → Run workflow

# Or manually
kubectl apply -k overlays/qa/ -n ecombaker-qa-namespace
```

## Traffic Flow Comparison

### Before (Direct LoadBalancer):
```
Domain → DNS (138.197.254.45)
    ↓
LoadBalancer: springboot-app-service-qa ($12/month)
    ↓
Application Pods

Cost: $12/month per service
```

### After (With Ingress):
```
Domain → DNS (New LoadBalancer IP)
    ↓
LoadBalancer: ingress-nginx-controller ($12/month)
    ↓
NGINX Ingress Controller (reads rules)
    ↓
Ingress Resources (routing rules)
    ↓
ClusterIP Services (no cost)
    ↓
Application Pods

Cost: $12/month total (shared by all services)
```

## Commands to Change Service Type

### Option 1: Edit Service Directly
```bash
# Get current service
kubectl get svc springboot-app-service-qa -o yaml > service-backup.yaml

# Edit the service
kubectl edit svc springboot-app-service-qa

# Change:
# type: LoadBalancer → type: ClusterIP
# Save and exit
```

### Option 2: Update YAML File
Edit your service YAML file in the store-pilot repo:

```bash
# File: k8s/qa/service.yaml
# Change:
spec:
  type: LoadBalancer  # Remove or change to ClusterIP
  
# To:
spec:
  type: ClusterIP
  
# Apply:
kubectl apply -f k8s/qa/service.yaml
```

## Verification

### Check LoadBalancers
```bash
# Should only see ingress-nginx-controller
kubectl get svc -A | grep LoadBalancer
```

### Check Ingress Status
```bash
# Should show the new LoadBalancer IP
kubectl get ingress -A
```

### Test Traffic
```bash
# Get LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with Host header
curl -H "Host: store1.qa.ecombaker.com" http://$EXTERNAL_IP/actuator/health
```

## Troubleshooting

### LoadBalancer IP Stuck on `<pending>`
```bash
# Check DigitalOcean console - may take 2-3 minutes
# Or check events:
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'
```

### After Changing Service Type, Getting 503 Errors
```bash
# Make sure service name matches ingress backend:
kubectl get ingress ecombaker-ingress -n ecombaker-qa-namespace -o yaml | grep "service:"

# Should match:
kubectl get svc -n ecombaker-qa-namespace
```

### Old LoadBalancer Still Exists
```bash
# List all LoadBalancers
kubectl get svc -A | grep LoadBalancer

# Delete old service LoadBalancer
kubectl delete svc springboot-app-service-qa

# Or change to ClusterIP:
kubectl patch svc springboot-app-service-qa -p '{"spec":{"type":"ClusterIP"}}'
```

## Cost Optimization

**Before ingress:** Multiple LoadBalancers
- App LoadBalancer: $12/month
- Frontend LoadBalancer: $12/month
- API LoadBalancer: $12/month
- **Total: $36/month**

**After ingress:** Single LoadBalancer
- Ingress LoadBalancer: $12/month
- All services use ClusterIP (free)
- **Total: $12/month**
- **Savings: $24/month = $288/year** 💰

## Rollback Plan

If something goes wrong:

1. **Keep old LoadBalancer service running** until ingress is verified
2. **Update DNS back** to old LoadBalancer IP
3. **Delete ingress controller** if needed:
   ```bash
   kubectl delete namespace ingress-nginx
   ```
4. **Restore service** to LoadBalancer type if needed

## Best Practices

1. **Test in dev first** before applying to qa/prod
2. **Keep DNS TTL low** during migration (5 minutes)
3. **Monitor traffic** during DNS propagation
4. **Keep old LoadBalancer** for 24 hours as backup
5. **Document the new IP** in your DNS records
