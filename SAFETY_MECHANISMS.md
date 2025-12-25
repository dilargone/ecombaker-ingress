# LoadBalancer Safety Mechanisms

## Problem We're Solving

**What happened**: The LoadBalancer with IP `138.197.254.45` was accidentally deleted, causing the IP to be released back to DigitalOcean's pool and potentially lost forever.

**Why it's critical**: 
- LoadBalancer IPs are expensive ($12/month each)
- DNS records point to these IPs
- Losing an IP means updating DNS across all services
- DNS propagation can take 24-48 hours
- Customer-facing downtime

## Safety Mechanisms Implemented

### 1. **Safe Migration Workflow** (`migrate-loadbalancer.yml`)

**Purpose**: Migrate from direct LoadBalancer to ingress while preserving the existing IP.

**Safety Features**:

#### ✅ Pre-flight Validation
```yaml
inputs:
  existing_loadbalancer_ip: # REQUIRED - forces you to specify IP explicitly
  existing_service_name: # REQUIRED - identifies what you're migrating
  confirm_migration: # REQUIRED - must type "MIGRATE" to proceed
```

**What it does**:
1. **Validates service exists** before doing anything
2. **Confirms IP matches** what you specified
3. **Creates automatic backup** of the service YAML
4. **Uploads backup as artifact** (retained for 90 days)
5. **Atomic swap** - deletes old, creates new with same IP immediately
6. **Verifies IP assignment** - fails if wrong IP is assigned
7. **Auto-deploys ingress resources** on success

#### ✅ Automatic Backups
Every migration creates a timestamped backup:
```
backup-springboot-app-service-qa-20251225-223015.yaml
```

Stored as GitHub Actions artifact for 90 days.

#### ✅ Confirmation Gates
You must type **exactly** "MIGRATE" to proceed. Typos = cancellation.

#### ✅ IP Validation
```bash
Expected IP: 138.197.254.45
Actual IP:   138.197.254.45
✅ Validation passed
```

If IPs don't match → workflow fails before any changes.

#### ✅ Rollback Instructions
On failure, workflow automatically displays rollback steps.

---

### 2. **Rollback Workflow** (`rollback-loadbalancer.yml`)

**Purpose**: Instantly restore the previous state if migration fails.

**How to use**:
1. Go to GitHub Actions → "Rollback LoadBalancer Migration"
2. Select environment (dev/qa/prod)
3. Enter the **run number** of the migration workflow (find in Actions history)
4. Type "ROLLBACK" to confirm
5. Click "Run workflow"

**What it does**:
1. Downloads the backup artifact from the specified workflow run
2. Deletes the ingress controller namespace
3. Restores the original LoadBalancer service from backup
4. Waits for IP assignment
5. Verifies restoration

**Safety**: Also requires typing "ROLLBACK" to confirm.

---

### 3. **Updated Install Workflow** (already exists)

**New feature**: Optional `loadbalancer_ip` input field

```yaml
inputs:
  loadbalancer_ip:
    description: 'LoadBalancer IP (optional - leave empty for auto-assign)'
    type: string
```

**When to use**:
- ✅ Fresh installation → Leave empty (auto-assign)
- ✅ Migration → Use the safe migration workflow instead
- ⚠️ Manual control → Specify IP (advanced users only)

---

## How to Safely Migrate (Step-by-Step)

### Option A: Using the Safe Migration Workflow (RECOMMENDED)

1. **Go to GitHub Actions** → "Migrate LoadBalancer to Ingress (Safe)"

2. **Fill in the form**:
   ```
   Environment: qa
   Existing LoadBalancer IP: 138.197.254.45
   Existing service name: springboot-app-service-qa
   Existing namespace: default
   Confirm migration: MIGRATE
   ```

3. **Click "Run workflow"**

4. **Monitor the workflow** - it will:
   - Validate your inputs
   - Create a backup
   - Install ingress controller
   - Swap the services atomically
   - Verify IP preservation
   - Deploy ingress resources

5. **If it succeeds** ✅:
   - Your IP is preserved
   - Traffic flows through ingress
   - No DNS changes needed
   - Backup is saved for 90 days

6. **If it fails** ❌:
   - Check the workflow logs for the reason
   - Use the rollback workflow to restore
   - Or manually apply the backup

### Option B: Manual Migration (Advanced)

⚠️ **Not recommended** - use the safe workflow instead!

But if you must:

```bash
# 1. Backup
kubectl get svc springboot-app-service-qa -n default -o yaml > backup.yaml

# 2. Note the IP
PRESERVED_IP=$(kubectl get svc springboot-app-service-qa -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "IP to preserve: $PRESERVED_IP"

# 3. Install ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/do/deploy.yaml

# 4. Wait for pods
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# 5. Delete old service
kubectl delete svc springboot-app-service-qa -n default --wait=false

# 6. Delete auto-created ingress service
kubectl delete svc ingress-nginx-controller -n ingress-nginx --wait=false

# 7. Create service with preserved IP
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  externalTrafficPolicy: Local
  loadBalancerIP: $PRESERVED_IP
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: http
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: LoadBalancer
EOF

# 8. Verify IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

## Best Practices

### ✅ DO:
- Use the "Migrate LoadBalancer to Ingress (Safe)" workflow
- Always download backups after successful migrations
- Test migrations in dev environment first
- Schedule migrations during low-traffic periods
- Keep backup artifacts until you're confident the migration is stable

### ❌ DON'T:
- Don't manually delete LoadBalancer services without a backup
- Don't delete services without knowing their IP first
- Don't assume IPs will be available after deletion
- Don't skip the confirmation prompts
- Don't delete the ingress controller namespace without a rollback plan

---

## Recovery Procedures

### Scenario 1: Migration Failed, IP Lost

**Symptoms**:
- Workflow shows IP mismatch
- Got `159.89.216.125` instead of `138.197.254.45`

**Solution**:
```bash
# Option A: Use the new IP
1. Update DNS to point to the new IP
2. Wait for DNS propagation
3. Delete old DNS record

# Option B: Rollback
1. Use the rollback workflow
2. Restore original LoadBalancer
3. Try migration again later or contact DO support
```

### Scenario 2: Service Deleted Accidentally

**Symptoms**:
- Service not found
- No backup exists

**Solution**:
```bash
# If you have the old IP:
1. Create a new LoadBalancer service with that IP (might not work)
2. If IP lost, create new service with auto-assigned IP
3. Update DNS

# If you have a backup file:
kubectl apply -f backup-springboot-app-service-qa-20251225.yaml
```

### Scenario 3: Ingress Controller Not Working

**Symptoms**:
- 502/503 errors
- Ingress controller pods crashing
- No route to host

**Solution**:
```bash
# Quick rollback:
1. Go to GitHub Actions → "Rollback LoadBalancer Migration"
2. Enter the migration workflow run number
3. Type "ROLLBACK" and run

# Or manually:
kubectl delete namespace ingress-nginx
kubectl apply -f backup.yaml
```

---

## Monitoring & Verification

### Check Current State:
```bash
# All LoadBalancers
kubectl get svc -A | grep LoadBalancer

# Specific ingress
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Ingress resources
kubectl get ingress -A

# DNS resolution
dig +short store1.qa.ecombaker.com
```

### Health Checks:
```bash
# Controller health
kubectl get pods -n ingress-nginx

# Ingress backend health
kubectl get ingress -A -o wide

# Test traffic
curl -I http://store1.qa.ecombaker.com/actuator/health
```

---

## Cost Tracking

### Before Migration:
- Direct LoadBalancer: $12/month
- **Total: $12/month**

### During Migration (if done wrong):
- Old LoadBalancer: $12/month
- Ingress LoadBalancer: $12/month
- **Total: $24/month** ❌

### After Migration (correct):
- Ingress LoadBalancer: $12/month
- **Total: $12/month** ✅

### Cost Savings:
Using the safe migration workflow ensures you never pay for two LoadBalancers.

---

## Frequently Asked Questions

### Q: Can I reuse a LoadBalancer IP after deleting it?
**A**: Maybe. Once deleted, the IP goes back to DO's pool. It might be available for a few minutes, but could be assigned to another customer at any time.

### Q: What if I deleted my service and lost the IP?
**A**: You'll need to update DNS to the new IP. There's no guaranteed way to get the old IP back.

### Q: How long are backups retained?
**A**: GitHub Actions artifacts are kept for 90 days by default.

### Q: Can I test the migration without affecting production?
**A**: Yes! Run the migration in dev environment first, then qa, then prod.

### Q: What's the expected downtime?
**A**: ~30-60 seconds during the atomic service swap.

### Q: Can I cancel a migration mid-way?
**A**: Yes, but if the old service is already deleted, you'll need to use the rollback workflow.

---

## Summary

These safety mechanisms ensure:
1. ✅ **No accidental IP loss** - validation before any changes
2. ✅ **Automatic backups** - every migration creates a restore point
3. ✅ **One-click rollback** - undo any migration instantly
4. ✅ **Confirmation gates** - prevents typos and misclicks
5. ✅ **Cost protection** - atomic swap prevents double billing
6. ✅ **Zero-DNS-change migration** - preserves existing IPs

**Use the workflows, follow the process, and you'll never lose an IP again!**
