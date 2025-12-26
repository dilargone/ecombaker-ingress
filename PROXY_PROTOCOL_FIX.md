# NGINX Ingress PROXY Protocol Fix

## Problem

The NGINX ingress controller was configured with `use-proxy-protocol: "true"`, but the DigitalOcean LoadBalancer wasn't sending PROXY protocol headers. This caused:

- **Error**: `broken header: "GET /actuator/health HTTP/1.1..." while reading PROXY protocol`
- **Symptom**: Empty replies from server (HTTP 52 error)
- **Impact**: All ingress traffic failed to reach backend services

## Root Cause

The [PROXY protocol](https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt) is used by load balancers to preserve client IP information. When enabled in NGINX:

1. NGINX expects the first bytes of a connection to be PROXY protocol headers
2. If it receives regular HTTP instead, it tries to parse HTTP as PROXY protocol
3. This results in "broken header" errors and connection termination

DigitalOcean LoadBalancers do not send PROXY protocol headers by default, so this must be disabled in the ingress controller.

## Solution

### Manual Fix (Already Applied)

```bash
# Disable PROXY protocol in ingress controller
kubectl patch configmap ingress-nginx-controller -n ingress-nginx \
  --type merge \
  -p '{"data":{"use-proxy-protocol":"false"}}'

# Restart controller to apply changes
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

# Wait for rollout
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

### Automated Fix via GitHub Actions

Use the workflow: `.github/workflows/fix-proxy-protocol.yml`

**To run:**
1. Go to GitHub Actions in ecombaker-ingress-repo
2. Select "Fix NGINX Ingress Proxy Protocol" workflow
3. Click "Run workflow"
4. Select `enable_proxy_protocol: false` (default)
5. Run

## Verification

### Check Current Configuration

```bash
kubectl get configmap ingress-nginx-controller -n ingress-nginx -o yaml | grep use-proxy-protocol
```

**Expected output:**
```yaml
use-proxy-protocol: "false"
```

### Test Ingress Connectivity

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test connection
curl -v -H "Host: store1.qa.ecombaker.com" http://$INGRESS_IP/swagger-ui/index.html
```

**Expected**: HTTP 200 response

### Check Logs for Errors

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50 | grep -i error
```

**Should NOT see**: "broken header" or "reading PROXY protocol" errors

## When to Enable PROXY Protocol

Enable `use-proxy-protocol: "true"` **only if**:

1. Your LoadBalancer is configured to send PROXY protocol headers
2. You need to preserve client IP addresses for rate limiting or logging
3. You have verified your LoadBalancer supports PROXY protocol v1 or v2

For DigitalOcean LoadBalancers without PROXY protocol configuration, **keep it disabled**.

## Related Configuration

The ingress controller ConfigMap also has:
- `allow-snippet-annotations: "false"` - Security: Disables custom NGINX snippets
- Other settings can be added as needed

## Impact of This Fix

✅ **Before Fix:**
- All HTTP requests → "Empty reply from server" (curl error 52)
- Ingress logs showed "broken header" errors
- No traffic reached backend services

✅ **After Fix:**
- HTTP 200 for Swagger UI
- HTTP 403 for protected endpoints (expected from Spring Security)
- Traffic correctly routed to backend pods
- Ingress logs clean (except DNS errors for non-existent frontend service)

## See Also

- [NGINX Ingress ConfigMap Documentation](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/)
- [PROXY Protocol Specification](https://www.haproxy.org/download/1.8/doc/proxy-protocol.txt)
- [DigitalOcean LoadBalancer Documentation](https://docs.digitalocean.com/products/networking/load-balancers/)
