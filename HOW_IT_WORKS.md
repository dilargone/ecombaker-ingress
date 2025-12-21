# How Ingress Routing & Redirects Work

## 🔄 Traffic Flow Overview

```
Internet Traffic
       ↓
   DNS Lookup
       ↓
Load Balancer (External IP)
       ↓
NGINX Ingress Controller
       ↓
[Automatic Redirects & Routing]
       ↓
Backend Services
```

## 1️⃣ HTTP → HTTPS Redirect (Automatic)

**Configuration:**
```yaml
nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

**How it works:**
- User types: `http://store1.ecombaker.com/api/products`
- Ingress automatically redirects to: `https://store1.ecombaker.com/api/products`
- **HTTP Status: 301 Permanent Redirect**
- All traffic is forced to use HTTPS for security

**Example:**
```bash
# Request HTTP
curl -I http://store1.ecombaker.com/api/products

# Response
HTTP/1.1 308 Permanent Redirect
Location: https://store1.ecombaker.com/api/products
```

## 2️⃣ Path-Based Routing

### API Traffic → Backend Service

**Pattern:** `*.ecombaker.com/api/*`

```
Request:  https://store1.ecombaker.com/api/user/auth
          ↓
Ingress matches: path: /api (Prefix)
          ↓
Routes to: pilot-service:8080
          ↓
Backend receives: /api/user/auth
```

**Configuration:**
```yaml
- path: /api
  pathType: Prefix
  backend:
    service:
      name: pilot-service
      port:
        number: 8080
```

### App Traffic → Frontend Service

**Pattern:** `*.ecombaker.com/app/*`

```
Request:  https://store1.ecombaker.com/app/dashboard
          ↓
Ingress matches: path: /app (Prefix)
          ↓
Routes to: pilot-frontend-service:80
          ↓
Frontend serves: /app/dashboard
```

**Configuration:**
```yaml
- path: /app
  pathType: Prefix
  backend:
    service:
      name: pilot-frontend-service
      port:
        number: 80
```

## 3️⃣ Multi-Tenant Subdomain Routing

**Wildcard Host:** `*.ecombaker.com`

This allows ANY subdomain to work:

```
store1.ecombaker.com/api/products  → pilot-service:8080
store2.ecombaker.com/api/products  → pilot-service:8080
myshop.ecombaker.com/api/products  → pilot-service:8080
```

**How your backend handles tenants:**
1. Ingress forwards the original `Host` header
2. Your `TenantFilter` extracts the subdomain
3. Backend sets `TenantContext` for that request

**Example request flow:**
```
User → https://store1.ecombaker.com/api/products
       ↓
Ingress → Forwards to pilot-service:8080 with headers:
          Host: store1.ecombaker.com
          X-Forwarded-Host: store1.ecombaker.com
       ↓
TenantFilter → Extracts "store1.ecombaker.com"
       ↓
Database Query → WHERE tenant_id = (from store1 domain)
```

## 4️⃣ SSL/TLS Certificate Handling

**Wildcard Certificate:** `*.ecombaker.com`

```yaml
tls:
  - hosts:
    - "*.ecombaker.com"
    - ecombaker.com
    secretName: ecombaker-tls-secret
```

**How it works:**
1. **User connects** to `https://store1.ecombaker.com`
2. **cert-manager** automatically requests certificate from Let's Encrypt
3. **Ingress** serves the wildcard certificate `*.ecombaker.com`
4. **Browser** validates certificate and establishes secure connection
5. **Traffic** is encrypted end-to-end

**Certificate lifecycle:**
- Automatically requested on first deployment
- Auto-renewed before expiration (90 days)
- Works for ALL subdomains (store1, store2, etc.)

## 5️⃣ Rate Limiting (Automatic)

**Configuration:**
```yaml
nginx.ingress.kubernetes.io/limit-rps: "100"
nginx.ingress.kubernetes.io/limit-connections: "50"
```

**How it works:**
- **Per IP**: Maximum 100 requests per second
- **Concurrent**: Maximum 50 simultaneous connections per IP
- **Exceeds limit**: Returns `HTTP 503 Service Unavailable`

**Example:**
```bash
# User sends 150 requests/second
# First 100 requests → Processed ✅
# Next 50 requests  → Rejected with 503 ❌
```

## 6️⃣ CORS Handling (Automatic)

**Configuration:**
```yaml
nginx.ingress.kubernetes.io/enable-cors: "true"
nginx.ingress.kubernetes.io/cors-allow-origin: "https://*.ecombaker.com"
nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, PATCH, OPTIONS"
nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
```

**How it works:**
1. **Browser** sends OPTIONS preflight request
2. **Ingress** automatically responds with CORS headers:
   ```
   Access-Control-Allow-Origin: https://store1.ecombaker.com
   Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS
   Access-Control-Allow-Credentials: true
   ```
3. **Browser** allows the actual request

**Example:**
```bash
# Preflight request
curl -X OPTIONS https://store1.ecombaker.com/api/products \
  -H "Origin: https://store1.ecombaker.com" \
  -H "Access-Control-Request-Method: POST"

# Response includes CORS headers automatically
```

## 7️⃣ Complete Request Flow Example

### Scenario: User logs into Store1

```
Step 1: User enters URL
   ┌─────────────────────────────────────────┐
   │ Browser: http://store1.ecombaker.com    │
   └─────────────────┬───────────────────────┘
                     ↓
Step 2: DNS Resolution
   ┌─────────────────────────────────────────┐
   │ DNS: store1.ecombaker.com → 159.65.93.198 │
   └─────────────────┬───────────────────────┘
                     ↓
Step 3: HTTP → HTTPS Redirect
   ┌─────────────────────────────────────────┐
   │ Ingress: 301 → https://store1.ecombaker.com │
   └─────────────────┬───────────────────────┘
                     ↓
Step 4: SSL/TLS Handshake
   ┌─────────────────────────────────────────┐
   │ Certificate: *.ecombaker.com (valid ✓)  │
   └─────────────────┬───────────────────────┘
                     ↓
Step 5: User clicks "Login" - POST to /api/user/auth
   ┌─────────────────────────────────────────┐
   │ POST https://store1.ecombaker.com/api/user/auth │
   └─────────────────┬───────────────────────┘
                     ↓
Step 6: Ingress Routing
   ┌─────────────────────────────────────────┐
   │ Path: /api → pilot-service:8080         │
   └─────────────────┬───────────────────────┘
                     ↓
Step 7: Backend Processing
   ┌─────────────────────────────────────────┐
   │ TenantFilter: Extract "store1.ecombaker.com" │
   │ TenantContext: Set tenant_id = UUID     │
   │ AuthService: Authenticate user          │
   │ Response: JWT token                     │
   └─────────────────┬───────────────────────┘
                     ↓
Step 8: Response to Browser
   ┌─────────────────────────────────────────┐
   │ HTTP 200 OK + JWT token                 │
   │ Browser stores token in localStorage    │
   └─────────────────────────────────────────┘
```

## 8️⃣ Path Routing Examples

### All Possible Routes

| User Request | Ingress Matches | Routes To | Port | Description |
|--------------|----------------|-----------|------|-------------|
| `store1.ecombaker.com/api/products` | `/api` | `pilot-service` | 8080 | Backend API |
| `store1.ecombaker.com/app/dashboard` | `/app` | `pilot-frontend-service` | 80 | Frontend app |
| `store1.ecombaker.com/actuator/health` | `/actuator` | `pilot-service` | 8080 | Health check |
| `store1.ecombaker.com/swagger-ui/` | `/swagger-ui` | `pilot-service` | 8080 | API docs |
| `store1.ecombaker.com/v3/api-docs` | `/v3/api-docs` | `pilot-service` | 8080 | OpenAPI spec |
| `ecombaker.com/` | `/` | `pilot-frontend-service` | 80 | Landing page |

### What Happens with Unmatched Paths?

```bash
# Request to unmatched path
https://store1.ecombaker.com/random-path

# Response: 404 Not Found (from ingress, not backend)
```

## 9️⃣ Environment Differences

### Production
```yaml
Domain: *.ecombaker.com
Rate Limit: 100 req/s
CORS Origin: https://*.ecombaker.com (strict)
Certificate: letsencrypt-prod (trusted)
```

### QA
```yaml
Domain: *.qa.ecombaker.com
Rate Limit: 200 req/s
CORS Origin: https://*.qa.ecombaker.com
Certificate: letsencrypt-prod (trusted)
```

### Dev
```yaml
Domain: *.dev.ecombaker.com
Rate Limit: None
CORS Origin: * (allow all)
Certificate: letsencrypt-staging (test cert)
```

## 🔟 Debugging Traffic Flow

### Check if HTTP → HTTPS redirect works
```bash
curl -I http://store1.ecombaker.com/api/health
# Should return: 308 Permanent Redirect
# Location: https://store1.ecombaker.com/api/health
```

### Check SSL certificate
```bash
openssl s_client -connect store1.ecombaker.com:443 -servername store1.ecombaker.com | grep subject
# Should show: subject=CN=*.ecombaker.com
```

### Check routing (with Host header)
```bash
# Test API routing
curl -H "Host: store1.ecombaker.com" https://<EXTERNAL-IP>/api/actuator/health

# Test frontend routing
curl -H "Host: store1.ecombaker.com" https://<EXTERNAL-IP>/app/
```

### Check rate limiting
```bash
# Send 150 requests quickly
for i in {1..150}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://store1.ecombaker.com/api/health &
done
# First 100 should return 200
# Next 50 should return 503 (rate limited)
```

## 📊 Summary: What Ingress Does Automatically

✅ **HTTP → HTTPS redirect** (301/308 status)  
✅ **SSL/TLS termination** (decrypts HTTPS, sends HTTP to backend)  
✅ **Path-based routing** (/api → backend, /app → frontend)  
✅ **Subdomain routing** (any subdomain works with wildcard)  
✅ **Rate limiting** (per IP, per second)  
✅ **CORS headers** (automatic OPTIONS response)  
✅ **Load balancing** (if multiple backend pods)  
✅ **Health checks** (removes unhealthy backends)  
✅ **Connection limits** (prevents overload)  
✅ **Request buffering** (handles large uploads)  
✅ **WebSocket support** (long-lived connections)  
✅ **Compression** (gzip responses)

## 🚀 What Your Backend Still Needs to Handle

- ❌ **Tenant extraction** (from Host header) → Your `TenantFilter`
- ❌ **Authentication** (JWT validation) → Your `JWTAuthFilter`
- ❌ **Business logic** (queries, processing) → Your services
- ❌ **Database filtering** (WHERE tenant_id = X) → Your repositories

The ingress is a **smart router**, not a **business logic handler**! 🎯
