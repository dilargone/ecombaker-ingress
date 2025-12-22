# How to Enable SSL/TLS Certificates Later

## Current Status

**SSL/TLS is currently DISABLED** to simplify initial setup. Your ingress is configured for **HTTP only** (port 80).

- ✅ Ingress works without certificates
- ✅ Traffic flows via HTTP (not HTTPS)
- ✅ No certificate management needed right now
- ✅ Faster initial deployment

## What's Been Disabled

1. **cert-manager.io/cluster-issuer** annotation (commented out)
2. **force-ssl-redirect** annotation (commented out)
3. **TLS section** in ingress spec (commented out)
4. **CORS origins** changed from `https://` to `http://`

## When You're Ready to Enable SSL

### Step 1: Install cert-manager

```bash
# Install cert-manager (handles Let's Encrypt certificates)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
# Should see: cert-manager, cert-manager-cainjector, cert-manager-webhook
```

### Step 2: Deploy the ClusterIssuer

```bash
# This creates the Let's Encrypt issuers
kubectl apply -f base/cluster-issuer.yaml

# Verify
kubectl get clusterissuer
# Should see: letsencrypt-prod, letsencrypt-staging
```

### Step 3: Uncomment SSL Configuration

**For base/ingress.yaml:**
```yaml
metadata:
  annotations:
    # Uncomment these lines:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # Change CORS from http:// to https://
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://*.ecombaker.com"

spec:
  # Uncomment the TLS section:
  tls:
  - hosts:
    - "*.ecombaker.com"
    - ecombaker.com
    secretName: ecombaker-tls-secret
```

**For overlays/dev/ingress-patch.yaml:**
```yaml
metadata:
  annotations:
    # Use staging for dev to avoid rate limits
    cert-manager.io/cluster-issuer: "letsencrypt-staging"

spec:
  tls:
  - hosts:
    - "*.dev.ecombaker.com"
    - dev.ecombaker.com
    secretName: ecombaker-dev-tls-secret
```

**For overlays/qa/ingress-patch.yaml:**
```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://*.qa.ecombaker.com"

spec:
  tls:
  - hosts:
    - "*.qa.ecombaker.com"
    - qa.ecombaker.com
    secretName: ecombaker-qa-tls-secret
```

### Step 4: Redeploy Ingress

```bash
# Deploy with SSL enabled
./scripts/deploy.sh dev   # or qa, prod

# Or manually:
kubectl apply -k overlays/dev
```

### Step 5: Verify Certificates

```bash
# Check certificate status
kubectl get certificate -n default

# Should see:
# NAME                        READY   SECRET                      AGE
# ecombaker-dev-tls-secret    True    ecombaker-dev-tls-secret    2m

# Check certificate details
kubectl describe certificate ecombaker-dev-tls-secret

# Verify HTTPS works
curl -v https://store1.dev.ecombaker.com/api/actuator/health
```

## Quick Enable Commands

### For Development (staging certificates)
```bash
# 1. Uncomment SSL lines in overlays/dev/ingress-patch.yaml
sed -i '' 's/# cert-manager.io/cert-manager.io/' overlays/dev/ingress-patch.yaml
sed -i '' 's/# tls:/tls:/' overlays/dev/ingress-patch.yaml
sed -i '' 's/http:/https:/' overlays/dev/ingress-patch.yaml

# 2. Deploy
./scripts/deploy.sh dev
```

### For QA/Production (prod certificates)
```bash
# 1. Uncomment SSL lines in overlays/qa/ingress-patch.yaml
sed -i '' 's/# cert-manager.io/cert-manager.io/' overlays/qa/ingress-patch.yaml
sed -i '' 's/# tls:/tls:/' overlays/qa/ingress-patch.yaml
sed -i '' 's/http:/https:/' overlays/qa/ingress-patch.yaml

# 2. Deploy
./scripts/deploy.sh qa
```

## Important Notes

### Let's Encrypt Rate Limits
- **Staging**: Use for dev/testing (no rate limits, but browser shows "untrusted")
- **Production**: Limited to 50 certificates per week per domain
- Always test with staging first!

### DNS Must Be Configured
SSL certificates require:
1. DNS A record pointing `*.ecombaker.com` → Your ingress IP
2. Domain must be publicly accessible
3. Port 80 must be open (for HTTP-01 challenge)

### Certificate Issuance Time
- First certificate: 2-5 minutes
- Renewal: Automatic (every 60 days)
- Check status: `kubectl get certificate`

### Troubleshooting

**Certificate not ready:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate events
kubectl describe certificate <cert-name>

# Check challenge status
kubectl get challenge
```

**Common issues:**
- DNS not configured → cert-manager can't validate domain
- Port 80 blocked → HTTP-01 challenge fails
- Rate limit hit → Use staging issuer
- Wrong email in cluster-issuer.yaml → Update and redeploy

## Testing SSL Configuration

### 1. Test with Staging First
```bash
# Deploy with staging issuer
kubectl apply -k overlays/dev

# Check certificate (will be untrusted but validates setup)
curl -k https://store1.dev.ecombaker.com/api/actuator/health
```

### 2. Switch to Production
```bash
# Update to production issuer
# Change: letsencrypt-staging → letsencrypt-prod
kubectl apply -k overlays/prod

# Verify trusted certificate
curl https://store1.ecombaker.com/api/actuator/health
```

## What Changes When SSL Is Enabled

**Without SSL (current):**
- ✅ URLs: `http://store1.dev.ecombaker.com/api/`
- ✅ Port 80 only
- ✅ No certificate management
- ❌ No encryption
- ❌ Browsers show "Not Secure"

**With SSL (after enabling):**
- ✅ URLs: `https://store1.dev.ecombaker.com/api/`
- ✅ Port 443 (HTTPS) + Port 80 (redirects to 443)
- ✅ Automatic certificate renewal
- ✅ Encrypted traffic
- ✅ Browsers show "Secure" 🔒

## Timeline for Enabling

**Recommended approach:**
1. **Week 1**: Deploy without SSL, test basic functionality
2. **Week 2**: Install cert-manager, test with staging certificates
3. **Week 3**: Enable production certificates for QA
4. **Week 4**: Enable production certificates for prod

**Fast-track (if DNS ready):**
1. Install cert-manager
2. Uncomment SSL config
3. Deploy and wait 2-5 minutes
4. Done! 🎉

## Files That Need Changes

When enabling SSL, edit these files:
- ✏️ `base/ingress.yaml` (uncomment cert-manager annotation, TLS section)
- ✏️ `overlays/dev/ingress-patch.yaml` (uncomment cert-manager annotation, TLS section)
- ✏️ `overlays/qa/ingress-patch.yaml` (uncomment cert-manager annotation, TLS section)
- ℹ️ `base/cluster-issuer.yaml` (already configured, no changes needed)

## Summary

**Current state:** HTTP only, no certificates needed  
**To enable SSL:** Install cert-manager → Uncomment config → Deploy  
**Time to enable:** 5-10 minutes (once DNS is ready)  
**Complexity:** Low (mostly uncommenting existing config)

You can work without SSL for now and enable it later with minimal changes! 🚀
