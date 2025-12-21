# Ecombaker Ingress Configuration

This repository contains Kubernetes Ingress configurations for routing traffic to the Ecombaker platform services.

## Overview

This ingress handles:
- **API Traffic**: `*.ecombaker.com/api/*` → Backend services
- **App Traffic**: `*.ecombaker.com/app/*` → Frontend services
- **Multi-tenant routing**: Wildcard subdomain support for tenant-specific routing

## Architecture

```
                                    ┌─────────────────────┐
                                    │   Ingress Controller │
                                    │      (nginx)         │
                                    └──────────┬───────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
         ┌──────────▼─────────┐    ┌──────────▼─────────┐    ┌──────────▼─────────┐
         │  *.ecombaker.com   │    │  *.ecombaker.com   │    │   ecombaker.com    │
         │      /api/*        │    │      /app/*        │    │      / (root)      │
         └──────────┬─────────┘    └──────────┬─────────┘    └──────────┬─────────┘
                    │                         │                          │
         ┌──────────▼─────────┐    ┌──────────▼─────────┐    ┌──────────▼─────────┐
         │  pilot-service     │    │ pilot-frontend     │    │ pilot-frontend     │
         │   (port 8080)      │    │   (port 80)        │    │   (port 80)        │
         └────────────────────┘    └────────────────────┘    └────────────────────┘
```

## Prerequisites

1. **Kubernetes cluster** with ingress controller installed
2. **NGINX Ingress Controller**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

3. **Cert-manager** for SSL/TLS certificates
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

4. **Backend services** running in the cluster:
   - `pilot-service` (Spring Boot backend on port 8080)
   - `pilot-frontend-service` (Frontend app on port 80)

## Directory Structure

```
.
├── README.md                      # This file
├── GITHUB_ACTIONS.md             # GitHub Actions setup guide
├── HOW_IT_WORKS.md               # Detailed explanation of routing
├── DIAGRAMS.md                   # Visual flow diagrams
├── SETUP.md                      # Setup and migration guide
├── QUICKREF.md                   # Quick reference commands
├── GETTING_STARTED.md            # Getting started guide
│
├── .github/
│   └── workflows/
│       ├── deploy.yml            # Automated deployment workflow
│       ├── pr-validation.yml     # Pull request validation
│       └── health-check.yml      # Certificate & health monitoring
│
├── base/
│   ├── ingress.yaml              # Base ingress configuration
│   ├── cluster-issuer.yaml       # Let's Encrypt certificate issuer
│   └── kustomization.yaml        # Base kustomize config
│
├── overlays/
│   ├── dev/
│   │   ├── ingress-patch.yaml    # Dev-specific overrides
│   │   └── kustomization.yaml
│   ├── qa/
│   │   ├── ingress-patch.yaml    # QA-specific overrides
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml    # Prod kustomization (uses base)
│
└── scripts/
    ├── deploy.sh                 # Deployment script
    └── verify.sh                 # Verification script
```

## Configuration

### Environment-Specific Settings

| Environment | Domain Pattern | Service Suffix | Rate Limit | CORS Origin |
|-------------|----------------|----------------|------------|-------------|
| Dev | `*.dev.ecombaker.com` | `-dev` | None | `*` |
| QA | `*.qa.ecombaker.com` | `-qa` | 200 req/s | `*.qa.ecombaker.com` |
| Production | `*.ecombaker.com` | (none) | 100 req/s | `*.ecombaker.com` |

## Deployment

### Quick Deploy (Manual)

```bash
# Deploy to production
kubectl apply -f base/

# Deploy to specific environment using Kustomize
kubectl apply -k overlays/dev/
kubectl apply -k overlays/qa/
kubectl apply -k overlays/prod/
```

### Using Deploy Script

```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to qa
./scripts/deploy.sh qa

# Deploy to production
./scripts/deploy.sh prod
```

### Automated Deployment with GitHub Actions

This repository includes automated CI/CD workflows:

#### Automatic Deployment
- **Push to `main`** → Automatically deploys to **Development**

#### Manual Deployment
1. Go to **Actions** tab on GitHub
2. Select **Deploy Ingress** workflow
3. Click **Run workflow**
4. Choose environment (dev/qa/prod)
5. For production: Requires approval from reviewers

**See [GITHUB_ACTIONS.md](./GITHUB_ACTIONS.md) for complete setup guide.**

#### Continuous Monitoring
- Daily certificate expiry checks
- Ingress health monitoring
- Automatic issue creation for problems

## DNS Configuration

Configure DNS records to point to your ingress controller's load balancer IP:

```bash
# Get the external IP of your ingress controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Add DNS records
*.ecombaker.com       A      <EXTERNAL-IP>
*.dev.ecombaker.com   A      <EXTERNAL-IP>
*.qa.ecombaker.com    A      <EXTERNAL-IP>
ecombaker.com         A      <EXTERNAL-IP>
```

Or use CNAME if you have a hostname:
```
*.ecombaker.com       CNAME  <LOAD-BALANCER-HOSTNAME>
*.dev.ecombaker.com   CNAME  <LOAD-BALANCER-HOSTNAME>
*.qa.ecombaker.com    CNAME  <LOAD-BALANCER-HOSTNAME>
```

## SSL/TLS Certificates

This configuration uses **cert-manager** with **Let's Encrypt** for automatic SSL certificate provisioning.

### Certificate Issuers

- **Production**: `letsencrypt-prod` (used in prod and QA)
- **Staging**: `letsencrypt-staging` (used in dev)

Certificates are automatically requested and renewed by cert-manager based on the annotations in the ingress resource.

## Path Routing

### API Paths (`/api/*`)
Routes to backend service (`pilot-service:8080`)
- `POST /api/user/auth` - Authentication
- `POST /api/user/owner/register` - Store owner registration
- `GET /api/products` - Product listings
- etc.

### App Paths (`/app/*`)
Routes to frontend service (`pilot-frontend-service:80`)
- `/app/dashboard` - Dashboard UI
- `/app/products` - Product management UI
- `/app/orders` - Order management UI
- etc.

### Health & Monitoring
- `/actuator/health` - Spring Boot health check
- `/actuator/metrics` - Application metrics
- `/swagger-ui` - API documentation
- `/v3/api-docs` - OpenAPI specification

## Security Features

### CORS Configuration
- **Dev**: Permissive (`*`)
- **QA/Prod**: Restricted to same domain

### Rate Limiting
- **Production**: 100 requests/second per IP
- **QA**: 200 requests/second per IP
- **Dev**: No rate limiting

### SSL/TLS
- Force HTTPS redirect enabled
- TLS 1.2+ only
- HTTP/2 enabled

## Troubleshooting

### Check Ingress Status
```bash
kubectl get ingress
kubectl describe ingress ecombaker-ingress
```

### View Ingress Logs
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Test Connectivity
```bash
# Test API endpoint
curl -H "Host: store1.ecombaker.com" https://store1.ecombaker.com/api/actuator/health

# Test with tenant header (for local dev)
curl -H "X-Tenant-Domain: store1.ecombaker.com" https://store1.ecombaker.com/api/actuator/health
```

### Certificate Issues
```bash
# Check certificate status
kubectl get certificate
kubectl describe certificate ecombaker-tls-secret

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

## Monitoring

### Key Metrics
- Request rate per path
- Response times
- Error rates (4xx, 5xx)
- Certificate expiry dates

### Prometheus Annotations
The ingress controller exports metrics that can be scraped by Prometheus:
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "10254"
```

## Updating Configuration

1. Edit the appropriate file in `base/` or `overlays/`
2. Apply changes:
   ```bash
   kubectl apply -k overlays/prod/
   ```
3. Verify:
   ```bash
   ./scripts/verify.sh prod
   ```

## Rollback

```bash
# View revision history
kubectl rollout history ingress ecombaker-ingress

# Rollback to previous version
kubectl rollout undo ingress ecombaker-ingress
```

## Support

For issues or questions:
- Check the logs: `kubectl logs -n ingress-nginx`
- Review ingress status: `kubectl describe ingress`
- Contact: DevOps team

## Related Repositories

- [store-pilot](https://github.com/dilargone/store-pilot) - Backend API service
- [store-pilot-frontend](https://github.com/dilargone/store-pilot-frontend) - Frontend application

## License

Proprietary - Ecombaker Platform
