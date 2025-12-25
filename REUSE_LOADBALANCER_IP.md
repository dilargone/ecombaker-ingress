# Reusing Existing LoadBalancer IP for Ingress

## Problem
When installing NGINX Ingress Controller, it creates a **new LoadBalancer** with a **new IP address**, which means:
- You have to update DNS records
- You pay for TWO LoadBalancers during migration (~$24/month)
- Potential downtime during DNS propagation

## Solution
Reuse your existing LoadBalancer IP by specifying it during ingress controller installation.

## How It Works

### Step 1: Find Your Current LoadBalancer IP
```bash
kubectl get svc -A | grep LoadBalancer
```

Example output:
```
default    springboot-app-service-qa    LoadBalancer   10.109.22.29    138.197.254.45   80:30177/TCP
```

Your existing IP: **138.197.254.45**

### Step 2: Delete Old Service (IMPORTANT!)
Before installing ingress with this IP, you **must delete** the old service using that IP:

```bash
kubectl delete svc springboot-app-service-qa -n default
```

⚠️ **This will cause downtime** until the ingress controller takes over with the same IP.

**Best Practice**: Do this during a maintenance window or low-traffic period.

### Step 3: Install Ingress Controller with Existing IP

Go to **GitHub Actions** → **Install NGINX Ingress Controller** workflow

Set the inputs:
- **Environment**: `qa` (or dev/prod)
- **Install NGINX Ingress Controller**: ✅ `true`
- **Namespace**: `ingress-nginx` (default)
- **LoadBalancer IP**: `138.197.254.45` ← Enter your existing IP here

### Step 4: Verify IP Assignment

After the workflow completes, verify the ingress controller got the correct IP:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Expected output:
```
NAME                       TYPE           EXTERNAL-IP       PORT(S)
ingress-nginx-controller   LoadBalancer   138.197.254.45    80:32621/TCP,443:32123/TCP
```

✅ The EXTERNAL-IP should match your requested IP!

### Step 5: Deploy Ingress Resources

```bash
kubectl apply -k overlays/qa/ -n ecombaker-qa-namespace
```

### Step 6: Test Traffic

Since DNS already points to `138.197.254.45`, your site should work immediately:

```bash
curl http://store1.qa.ecombaker.com/actuator/health
```

## Benefits

✅ **No DNS changes needed** - traffic continues using the same IP  
✅ **No extra cost** - only one LoadBalancer instead of two  
✅ **Seamless migration** - minimal downtime  

## Architecture Comparison

### Before (Direct LoadBalancer):
```
DNS (138.197.254.45) → springboot-app-service-qa → App Pods
                       $12/month LoadBalancer
```

### During Migration (Two LoadBalancers):
```
DNS (138.197.254.45) → springboot-app-service-qa → App Pods
                       $12/month LoadBalancer

NEW (45.55.118.26)   → ingress-nginx-controller → Ingress → ClusterIP → App Pods
                       $12/month LoadBalancer
                       
Total: $24/month ❌
```

### After (Reusing IP):
```
DNS (138.197.254.45) → ingress-nginx-controller → Ingress → ClusterIP → App Pods
                       $12/month LoadBalancer
```

## Important Notes

### DigitalOcean Behavior
- When you delete a LoadBalancer service, DigitalOcean **releases the IP** back to the pool
- There's a **small window** (seconds to minutes) where the IP might be reassigned to another customer
- To minimize risk: delete the old service and immediately install the ingress controller

### Alternative Approach (Zero Downtime)
If you want zero downtime:

1. Create ingress with a NEW IP (auto-assign)
2. Update DNS to point to the new IP
3. Wait for DNS propagation (TTL dependent)
4. Delete the old LoadBalancer
5. (Optional) Later, switch ingress to use the old IP if preferred

This costs $12 extra during the migration period but eliminates downtime risk.

## Troubleshooting

### IP Doesn't Match After Installation
If the ingress controller gets a different IP than requested:

**Possible causes:**
1. The IP was already in use by another service
2. The IP was released and reassigned to another customer
3. The IP belongs to a different region/datacenter

**Solution:**
```bash
# Check what's using the IP
kubectl get svc -A -o wide | grep "138.197.254.45"

# If nothing found, the IP was lost - you'll need to:
# 1. Update DNS to new IP
# 2. Or delete ingress and try again quickly
```

### Old Service Still Exists
If you forgot to delete the old service first:

```bash
# You'll have TWO services competing for the same IP
# Delete the old one:
kubectl delete svc springboot-app-service-qa -n default

# The ingress controller should pick up the IP shortly
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
```

## When to Use This Feature

✅ **Use IP reuse when:**
- You want to keep existing DNS records
- You want to minimize migration complexity
- You're okay with brief downtime during the switch

❌ **Use auto-assign when:**
- You want zero downtime migration
- You don't mind updating DNS
- This is a new environment with no existing LoadBalancer

## Summary

The new GitHub Action input field **"LoadBalancer IP"** lets you:
- Reuse your existing LoadBalancer IP
- Avoid updating DNS records
- Save costs during migration
- Simplify the ingress migration process

Just remember: **delete the old service first** before installing the ingress controller!
