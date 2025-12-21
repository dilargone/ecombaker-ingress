# Quick Reference Guide

## Common Commands

### Deploy

```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to QA
./scripts/deploy.sh qa

# Deploy to production
./scripts/deploy.sh prod
```

### Verify

```bash
# Verify deployment
./scripts/verify.sh <environment>
```

### View Resources

```bash
# List all ingresses
kubectl get ingress

# Describe ingress
kubectl describe ingress ecombaker-ingress

# Get ingress in YAML format
kubectl get ingress ecombaker-ingress -o yaml

# View all resources with specific labels
kubectl get all -l app=ecombaker
```

### Certificates

```bash
# List certificates
kubectl get certificate

# Describe certificate
kubectl describe certificate ecombaker-tls-secret

# Check certificate status
kubectl get certificate ecombaker-tls-secret -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# View certificate details from secret
kubectl get secret ecombaker-tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Logs

```bash
# Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Follow logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# View recent logs (last 50 lines)
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```

### Testing

```bash
# Test health endpoint
curl -H "Host: store1.ecombaker.com" -H "X-Tenant-Domain: store1.ecombaker.com" https://159.65.93.198/actuator/health

# Test API endpoint
curl -X POST -H "Host: store1.ecombaker.com" -H "X-Tenant-Domain: store1.ecombaker.com" -H "Content-Type: application/json" https://159.65.93.198/api/user/auth

# Test with local hostname resolution (if DNS not configured)
curl --resolve store1.ecombaker.com:443:<EXTERNAL_IP> https://store1.ecombaker.com/actuator/health

# Test HTTP to HTTPS redirect
curl -I http://<EXTERNAL_IP>/api/actuator/health -H "Host: store1.ecombaker.com"
```

### Troubleshooting

```bash
# Get ingress controller external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Check ingress events
kubectl get events --sort-by='.lastTimestamp' | grep ingress

# Check if services exist
kubectl get svc pilot-service
kubectl get svc pilot-frontend-service

# Test service endpoints
kubectl get endpoints pilot-service

# Port forward to test backend directly
kubectl port-forward svc/pilot-service 8080:8080

# Check cert-manager webhook
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

### Updates & Rollback

```bash
# Apply changes
kubectl apply -k overlays/prod/

# Rollback ingress
kubectl rollout undo ingress ecombaker-ingress

# View rollout history
kubectl rollout history ingress ecombaker-ingress

# Delete and recreate
kubectl delete ingress ecombaker-ingress
kubectl apply -k overlays/prod/
```

### Debugging

```bash
# Get ingress nginx config
kubectl exec -n ingress-nginx <ingress-controller-pod> -- cat /etc/nginx/nginx.conf

# Check backend health from ingress controller
kubectl exec -n ingress-nginx <ingress-controller-pod> -- curl http://pilot-service:8080/actuator/health

# Check DNS resolution
nslookup store1.ecombaker.com
dig store1.ecombaker.com

# Test SSL certificate
openssl s_client -connect store1.ecombaker.com:443 -servername store1.ecombaker.com
```

## Quick Fixes

### Certificate Not Issuing

```bash
# Delete and recreate certificate
kubectl delete certificate ecombaker-tls-secret
kubectl apply -k overlays/prod/

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager
```

### 502 Bad Gateway

```bash
# Check backend service
kubectl get endpoints pilot-service

# Check backend pods
kubectl get pods -l app=pilot

# Check service logs
kubectl logs -l app=pilot --tail=50
```

### 404 Not Found

```bash
# Verify ingress paths
kubectl get ingress ecombaker-ingress -o yaml | grep -A 10 paths

# Check ingress controller config
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- nginx -T | grep -A 5 "server_name.*ecombaker"
```

### Rate Limiting Issues

```bash
# Check rate limit annotations
kubectl get ingress ecombaker-ingress -o yaml | grep limit

# Temporarily remove rate limiting
kubectl annotate ingress ecombaker-ingress nginx.ingress.kubernetes.io/limit-rps-

# Re-apply rate limiting
kubectl apply -k overlays/prod/
```

## Environment Variables

| Variable | Dev | QA | Prod |
|----------|-----|----|----|
| Domain | `*.dev.ecombaker.com` | `*.qa.ecombaker.com` | `*.ecombaker.com` |
| Backend Service | `pilot-service-dev` | `pilot-service-qa` | `pilot-service` |
| Frontend Service | `pilot-frontend-service-dev` | `pilot-frontend-service-qa` | `pilot-frontend-service` |
| Rate Limit | None | 200/s | 100/s |
| CORS Origin | `*` | `*.qa.ecombaker.com` | `*.ecombaker.com` |
| Cert Issuer | `letsencrypt-staging` | `letsencrypt-prod` | `letsencrypt-prod` |

## DNS Records Template

```
# For production
*.ecombaker.com      A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>
ecombaker.com        A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>

# For QA
*.qa.ecombaker.com   A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>
qa.ecombaker.com     A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>

# For Dev
*.dev.ecombaker.com  A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>
dev.ecombaker.com    A/CNAME    <EXTERNAL_IP_OR_HOSTNAME>
```

## Important URLs

- Health Check: `https://<domain>/actuator/health`
- API Docs: `https://<domain>/swagger-ui/`
- API Spec: `https://<domain>/v3/api-docs`
- Metrics: `https://<domain>/actuator/metrics`

## Support Contacts

- DevOps Team: devops@ecombaker.com
- Backend Team: backend@ecombaker.com
- Infrastructure Issues: Create ticket in JIRA

---

**Note**: Replace `<EXTERNAL_IP>` and `<domain>` with actual values from your deployment.
