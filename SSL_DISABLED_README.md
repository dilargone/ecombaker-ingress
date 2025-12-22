# SSL/TLS DISABLED - HTTP Only Configuration

## ✅ What's Been Changed

All SSL/TLS certificate configurations have been **commented out** and disabled. Your ingress now works with **HTTP only** (no HTTPS).

### Files Modified

1. **`base/ingress.yaml`**
   - ❌ Commented out: `cert-manager.io/cluster-issuer`
   - ❌ Commented out: `force-ssl-redirect`
   - ❌ Commented out: entire `tls:` section
   - ✅ Changed CORS: `https://` → `http://`

2. **`overlays/dev/ingress-patch.yaml`**
   - ❌ Commented out: `cert-manager.io/cluster-issuer: "letsencrypt-staging"`
   - ❌ Commented out: entire `tls:` section
   - ✅ CORS already allows `*` (no change needed)

3. **`overlays/qa/ingress-patch.yaml`**
   - ❌ Commented out: `cert-manager.io/cluster-issuer: "letsencrypt-prod"`
   - ❌ Commented out: entire `tls:` section
   - ✅ Changed CORS: `https://` → `http://`

4. **`base/cluster-issuer.yaml`**
   - ℹ️ No changes (kept for future use)

## 🚀 Current Setup

**Your ingress now works with:**

```
✅ HTTP only (port 80)
✅ No certificate management needed
✅ No cert-manager required
✅ Simpler deployment
✅ All routing still works
❌ No HTTPS encryption
❌ Browsers show "Not Secure"
```

## 🌐 URL Format

### Before (with SSL):
```
https://store1.dev.ecombaker.com/api/products
https://store1.qa.ecombaker.com/app/
```

### Now (without SSL):
```
http://store1.dev.ecombaker.com/api/products
http://store1.qa.ecombaker.com/app/
```

## 📝 Testing Your Ingress (HTTP)

```bash
# Deploy the ingress
./scripts/deploy.sh dev

# Test API endpoint (HTTP)
curl http://store1.dev.ecombaker.com/api/actuator/health

# Test frontend (HTTP)
curl http://store1.dev.ecombaker.com/app/
```

## 🔐 When You Want SSL Later

See the complete guide in **`ENABLE_SSL_LATER.md`**

**Quick steps:**
1. Install cert-manager: `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml`
2. Uncomment all `# cert-manager.io` and `# tls:` lines
3. Change `http://` back to `https://` in CORS settings
4. Redeploy: `./scripts/deploy.sh dev`
5. Wait 2-5 minutes for certificates

## 📊 What Still Works

**Everything works the same, just over HTTP instead of HTTPS:**

✅ Multi-tenant routing (`*.ecombaker.com`)  
✅ Path-based routing (`/api/*`, `/app/*`)  
✅ CORS configuration  
✅ Rate limiting (qa/prod)  
✅ Wildcard subdomain support  
✅ Load balancing  
✅ Health checks  
✅ WebSocket support  

**Only missing:**
❌ HTTPS encryption  
❌ SSL/TLS certificates  
❌ Browser "Secure" padlock  

## 🎯 Benefits of Disabling SSL for Now

1. **Faster deployment** - No waiting for certificate issuance
2. **Simpler setup** - No need to install cert-manager
3. **No DNS requirements** - Can test with `/etc/hosts` or IP address
4. **No rate limits** - Let's Encrypt has weekly limits
5. **Focus on functionality** - Test routing first, add security later

## ⚠️ Important Notes

### For Development/Testing
✅ HTTP is fine for:
- Local development
- Internal testing
- Behind a VPN
- Development environments

### For Production
❌ HTTP is NOT recommended for:
- User-facing applications
- Handling sensitive data
- Payment processing
- Public internet traffic

**Enable SSL before going to production!**

## 🔄 Deployment Differences

### Without SSL (Current)
```bash
./scripts/deploy.sh dev
# → Immediate deployment
# → Works right away
# → Access via http://
```

### With SSL (Future)
```bash
./scripts/deploy.sh dev
# → Deploys ingress
# → cert-manager requests certificate
# → Wait 2-5 minutes
# → Access via https://
```

## 📂 File Status

| File | SSL Status | Ready to Deploy |
|------|-----------|-----------------|
| `base/ingress.yaml` | Disabled | ✅ Yes |
| `base/cluster-issuer.yaml` | Commented (unused) | ℹ️ Not needed |
| `overlays/dev/ingress-patch.yaml` | Disabled | ✅ Yes |
| `overlays/qa/ingress-patch.yaml` | Disabled | ✅ Yes |
| `overlays/prod/kustomization.yaml` | Uses base (disabled) | ✅ Yes |

## 🎬 Next Steps

1. **Test HTTP configuration**
   ```bash
   ./scripts/deploy.sh dev
   curl http://store1.dev.ecombaker.com/api/actuator/health
   ```

2. **When ready for SSL** (later)
   - Read: `ENABLE_SSL_LATER.md`
   - Install cert-manager
   - Uncomment SSL configuration
   - Redeploy

3. **For now, focus on**
   - Application functionality
   - Routing configuration
   - Service setup
   - Testing workflows

---

**Current Mode**: HTTP Only (No SSL/TLS)  
**To Enable SSL**: See `ENABLE_SSL_LATER.md`  
**Deploy Command**: `./scripts/deploy.sh <env>`  
**Status**: ✅ Ready to use!
