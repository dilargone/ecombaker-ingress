# 🎉 Ecombaker Ingress Repository - Complete Setup

## 📁 Repository Structure

```
ecombaker-ingress-repo/
├── README.md                           # Main documentation
├── SETUP.md                            # Setup and migration guide
├── QUICKREF.md                         # Quick reference commands
├── .gitignore                          # Git ignore patterns
│
├── base/                               # Base Kustomize configuration
│   ├── ingress.yaml                    # Main ingress resource
│   ├── cluster-issuer.yaml             # Let's Encrypt certificate issuers
│   └── kustomization.yaml              # Kustomize base config
│
├── overlays/                           # Environment-specific overrides
│   ├── dev/
│   │   ├── ingress-patch.yaml          # Dev environment patches
│   │   └── kustomization.yaml          # Dev kustomization
│   ├── qa/
│   │   ├── ingress-patch.yaml          # QA environment patches
│   │   └── kustomization.yaml          # QA kustomization
│   └── prod/
│       └── kustomization.yaml          # Prod kustomization (uses base as-is)
│
└── scripts/
    ├── deploy.sh                       # Automated deployment script
    └── verify.sh                       # Deployment verification script
```

## 🚀 What This Repository Does

### Traffic Routing
- **`*.ecombaker.com/api/*`** → Routes to `pilot-service` (Spring Boot backend on port 8080)
- **`*.ecombaker.com/app/*`** → Routes to `pilot-frontend-service` (Frontend on port 80)

### Multi-Tenant Support
- Supports wildcard subdomains for tenant-specific routing
- Examples:
  - `store1.ecombaker.com/api/products`
  - `store2.ecombaker.com/app/dashboard`
  - `myshop.ecombaker.com/api/orders`

### Features
✅ Automatic SSL/TLS certificates via cert-manager  
✅ Force HTTPS redirect  
✅ CORS configuration  
✅ Rate limiting  
✅ WebSocket support  
✅ Health check endpoints  
✅ Swagger/API documentation routing  
✅ Environment-specific configurations

## 📝 Next Steps to Create Separate Repository

### Option 1: Create New GitHub Repository (Recommended)

```bash
# 1. Navigate to the ingress directory
cd /Users/dila.gurung.1987/IdeaProjects/store-pilot/ecombaker-ingress-repo

# 2. Initialize git
git init

# 3. Add all files
git add .

# 4. Initial commit
git commit -m "Initial commit: Kubernetes ingress configuration for Ecombaker platform

- Multi-tenant wildcard routing for *.ecombaker.com
- Supports /api/* and /app/* path routing
- Environment-specific configurations (dev, qa, prod)
- Automated deployment and verification scripts
- SSL/TLS with Let's Encrypt via cert-manager"

# 5. Create repository on GitHub
# Go to: https://github.com/new
# Repository name: ecombaker-ingress
# Don't initialize with README (we already have files)

# 6. Add remote and push
git remote add origin git@github.com:dilargone/ecombaker-ingress.git
git branch -M main
git push -u origin main
```

### Option 2: Move to Separate Directory First

```bash
# 1. Copy to separate location
cp -r /Users/dila.gurung.1987/IdeaProjects/store-pilot/ecombaker-ingress-repo \
      /Users/dila.gurung.1987/IdeaProjects/ecombaker-ingress

# 2. Navigate to new location
cd /Users/dila.gurung.1987/IdeaProjects/ecombaker-ingress

# 3. Follow steps 2-6 from Option 1
```

## 🔧 Configuration Before Deployment

### 1. Update Email in Cluster Issuer

Edit `base/cluster-issuer.yaml`:
```yaml
email: your-actual-email@ecombaker.com  # Change this!
```

### 2. Verify Service Names

Check that these match your actual Kubernetes service names:
- Production: `pilot-service`, `pilot-frontend-service`
- QA: `pilot-service-qa`, `pilot-frontend-service-qa`
- Dev: `pilot-service-dev`, `pilot-frontend-service-dev`

If different, update the YAML files in `base/` and `overlays/`.

### 3. Configure DNS

After deployment, get the external IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Then configure DNS records:
```
*.ecombaker.com       A      <EXTERNAL-IP>
*.qa.ecombaker.com    A      <EXTERNAL-IP>
*.dev.ecombaker.com   A      <EXTERNAL-IP>
```

## 🎯 Quick Start Guide

### Deploy to Development
```bash
./scripts/deploy.sh dev
./scripts/verify.sh dev
```

### Deploy to QA
```bash
./scripts/deploy.sh qa
./scripts/verify.sh qa
```

### Deploy to Production
```bash
./scripts/deploy.sh prod
./scripts/verify.sh prod
```

### Test the Deployment
```bash
# Test health endpoint
curl -H "Host: store1.ecombaker.com" -H "X-Tenant-Domain: store1.ecombaker.com" \
  https://<EXTERNAL-IP>/actuator/health

# Test API endpoint
curl -X POST -H "Host: store1.ecombaker.com" -H "X-Tenant-Domain: store1.ecombaker.com" \
  -H "Content-Type: application/json" \
  https://<EXTERNAL-IP>/api/user/auth
```

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Complete documentation with architecture, deployment, troubleshooting |
| `SETUP.md` | Step-by-step setup instructions, CI/CD integration, security best practices |
| `QUICKREF.md` | Quick reference for common kubectl commands and troubleshooting |
| This file | Overview and next steps summary |

## 🔐 Security Checklist

- [ ] Change email in `cluster-issuer.yaml`
- [ ] Review CORS settings for each environment
- [ ] Configure rate limiting based on your needs
- [ ] Set up RBAC policies in your cluster
- [ ] Never commit kubeconfig or secrets to git
- [ ] Use separate namespaces per environment (optional but recommended)
- [ ] Enable network policies in your cluster
- [ ] Set up monitoring and alerting for the ingress

## 🛠️ Prerequisites

Before deploying, ensure you have:
- [ ] Kubernetes cluster (1.19+)
- [ ] kubectl installed and configured
- [ ] NGINX Ingress Controller (or script will install)
- [ ] cert-manager (or script will install)
- [ ] Backend services deployed (`pilot-service`)
- [ ] Frontend services deployed (`pilot-frontend-service`)

## 📊 Environment Comparison

| Feature | Dev | QA | Production |
|---------|-----|-----|------------|
| Domain | `*.dev.ecombaker.com` | `*.qa.ecombaker.com` | `*.ecombaker.com` |
| Cert Issuer | Staging | Production | Production |
| Rate Limit | None | 200/s | 100/s |
| CORS | Allow all (`*`) | `*.qa.ecombaker.com` | `*.ecombaker.com` |
| Backend Service | `pilot-service-dev` | `pilot-service-qa` | `pilot-service` |
| Frontend Service | `pilot-frontend-service-dev` | `pilot-frontend-service-qa` | `pilot-frontend-service` |

## 🤝 Team Collaboration

Once the repository is on GitHub:

```bash
# Team members clone the repo
git clone git@github.com:dilargone/ecombaker-ingress.git
cd ecombaker-ingress

# Make scripts executable
chmod +x scripts/*.sh

# Deploy to their environment
./scripts/deploy.sh dev
```

## 📞 Support

For questions or issues:
1. Check `QUICKREF.md` for common problems
2. Review logs: `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx`
3. Open an issue on GitHub
4. Contact DevOps team

## ✅ Current Status

✅ Repository structure created  
✅ Base configuration complete  
✅ Environment overlays (dev, qa, prod) configured  
✅ Deployment scripts created and executable  
✅ Verification scripts ready  
✅ Documentation complete  
✅ .gitignore configured  
⏳ **Ready to push to GitHub!**

---

**Location**: `/Users/dila.gurung.1987/IdeaProjects/store-pilot/ecombaker-ingress-repo`

**Next Action**: Follow "Option 1" or "Option 2" above to create the GitHub repository!
