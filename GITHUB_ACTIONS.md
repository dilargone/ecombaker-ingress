# GitHub Actions Setup Guide

This repository includes automated CI/CD workflows for deploying and managing Kubernetes ingress resources.

## 📋 Workflows Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Deploy** | Push to main, Manual | Validates and deploys ingress to environments |
| **PR Validation** | Pull request | Validates changes before merge |
| **Health Check** | Daily schedule, Manual | Monitors certificate expiry and ingress health |

## 🔧 Setup Instructions

### 1. Required GitHub Secrets

Navigate to: **Settings → Secrets and variables → Actions → New repository secret**

Add the following secrets for each environment:

#### Development Environment
```
Name: KUBE_CONFIG_DEV
Value: <base64-encoded kubeconfig for dev cluster>
```

#### QA Environment
```
Name: KUBE_CONFIG_QA
Value: <base64-encoded kubeconfig for QA cluster>
```

#### Production Environment
```
Name: KUBE_CONFIG_PROD
Value: <base64-encoded kubeconfig for production cluster>
```

### 2. How to Get Kubeconfig

```bash
# Get your kubeconfig
cat ~/.kube/config | base64

# Or for specific context
kubectl config view --flatten --minify | base64
```

**⚠️ Important:** Never commit kubeconfig files to git!

### 3. Configure Environment Protection Rules

Go to: **Settings → Environments**

#### Development Environment
- Name: `development`
- Protection rules: None (auto-deploy on push to main)
- URL: `https://dev.ecombaker.com`

#### QA Environment
- Name: `qa`
- Protection rules:
  - ✅ Required reviewers (at least 1)
  - ✅ Wait timer: 5 minutes
- URL: `https://qa.ecombaker.com`

#### Production Environment
- Name: `production`
- Protection rules:
  - ✅ Required reviewers (at least 2)
  - ✅ Wait timer: 15 minutes
  - ✅ Deployment branches: Only `main`
- URL: `https://ecombaker.com`

## 🚀 Workflow Details

### 1. Deploy Workflow (`.github/workflows/deploy.yml`)

**Triggers:**
- Push to `main` branch
- Manual trigger via workflow dispatch

**Jobs:**

#### Validate
- Installs kubectl and kustomize
- Validates YAML syntax
- Dry-run applies to all environments
- Runs kubeval for strict validation

#### Deploy to Dev (Automatic)
- Runs on every push to `main`
- Applies dev overlay: `kubectl apply -k overlays/dev/`
- Waits for ingress to be ready
- Runs verification script

#### Deploy to QA (Manual)
- Requires manual approval via workflow dispatch
- Applies QA overlay: `kubectl apply -k overlays/qa/`
- Sends notification to QA team

#### Deploy to Prod (Manual + Approval)
- Requires manual trigger
- Needs QA deployment to succeed first
- Creates backup before deployment
- Runs smoke tests
- Auto-rollback on failure

**Usage:**

```bash
# Automatic deployment to dev
git push origin main

# Manual deployment to QA
# Go to Actions → Deploy Ingress → Run workflow
# Select environment: qa

# Manual deployment to production
# Go to Actions → Deploy Ingress → Run workflow
# Select environment: prod
# Requires approval from reviewers
```

### 2. PR Validation Workflow (`.github/workflows/pr-validation.yml`)

**Triggers:**
- Pull request to `main` branch

**Jobs:**

#### Lint
- Runs `yamllint` on all YAML files
- Checks formatting and syntax

#### Validate
- Validates manifests with `kubectl`
- Builds kustomize overlays
- Displays generated manifests in PR

#### Security Scan
- Runs Trivy security scanner
- Checks for misconfigurations
- Uploads results to GitHub Security tab

#### Test Scripts
- Validates bash script syntax
- Runs shellcheck for best practices

#### PR Comment
- Adds automated comment to PR
- Shows validation results
- Provides deployment instructions

**What Developers See:**

```markdown
## 🔍 Ingress Validation Results

### Validation Status
- ✅ YAML Lint: Passed
- ✅ Manifest Validation: Passed
- ✅ Script Tests: Passed

### Next Steps
After merge, this will be automatically deployed to Development.
```

### 3. Health Check Workflow (`.github/workflows/health-check.yml`)

**Triggers:**
- Daily at 2 AM UTC (cron)
- Manual trigger

**Jobs:**

#### Check Certificates
- Monitors SSL certificate status
- Checks expiry dates
- Creates GitHub issues if:
  - Certificate not ready
  - Certificate expires in < 30 days

#### Check Ingress Health
- Verifies ingress has external address
- Checks NGINX controller status
- Validates all replicas are ready

**Automated Issue Creation:**

If certificate expires soon:
```markdown
## ⚠️ SSL Certificate Expiring Soon - PRODUCTION

**Environment:** prod
**Days until expiry:** 25
**Action Required:** Monitor renewal process
```

## 📊 Workflow Visualization

### Deployment Flow

```
Developer → Push to main
    ↓
GitHub Actions: Validate
    ↓
✅ Pass → Deploy to Dev (automatic)
    ↓
Developer → Trigger QA deployment
    ↓
Reviewer → Approve QA deployment
    ↓
Deploy to QA
    ↓
Developer → Trigger Prod deployment
    ↓
Reviewers (2) → Approve Prod deployment
    ↓
Wait 15 minutes
    ↓
Deploy to Production
    ↓
Run smoke tests
    ↓
✅ Success / ❌ Auto-rollback
```

### Pull Request Flow

```
Developer → Create PR
    ↓
GitHub Actions
    ├─ Lint YAML files
    ├─ Validate manifests
    ├─ Security scan
    └─ Test scripts
    ↓
✅ All checks pass
    ↓
Bot comments on PR with results
    ↓
Reviewer approves
    ↓
Merge to main
    ↓
Automatic deployment to Dev
```

## 🎯 Usage Examples

### Scenario 1: Update Ingress Configuration

```bash
# 1. Create feature branch
git checkout -b feature/update-rate-limit

# 2. Edit ingress configuration
vim base/ingress.yaml

# 3. Commit and push
git add base/ingress.yaml
git commit -m "Update rate limit to 200 req/s"
git push origin feature/update-rate-limit

# 4. Create PR on GitHub
# GitHub Actions will automatically:
# - Validate your changes
# - Comment on PR with results

# 5. After approval, merge PR
# - Dev environment deploys automatically
# - QA/Prod require manual trigger
```

### Scenario 2: Deploy to Production

```bash
# 1. Go to GitHub Actions tab
# 2. Click "Deploy Ingress" workflow
# 3. Click "Run workflow"
# 4. Select:
#    - Branch: main
#    - Environment: prod
# 5. Click "Run workflow"
# 6. Wait for reviewer approval
# 7. Deployment proceeds after approval + 15 min wait
```

### Scenario 3: Check Certificate Status Manually

```bash
# 1. Go to GitHub Actions tab
# 2. Click "Certificate Check" workflow
# 3. Click "Run workflow"
# 4. View results in workflow logs
```

## 🔍 Monitoring & Debugging

### View Workflow Runs
```
GitHub → Actions tab → Select workflow → View run details
```

### Check Workflow Logs
```
Workflow run → Click on job name → Expand steps
```

### Manual Deployment (Bypass CI)
```bash
# If GitHub Actions is down, deploy manually:
kubectl apply -k overlays/prod/
./scripts/verify.sh prod
```

### Debug Failed Deployment
```bash
# Check workflow logs first
# Then check cluster directly:
kubectl get events --sort-by='.lastTimestamp'
kubectl describe ingress ecombaker-ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100
```

## 🛡️ Security Best Practices

### Secrets Management
- ✅ Use GitHub secrets for kubeconfig
- ✅ Rotate secrets every 90 days
- ✅ Use different service accounts per environment
- ✅ Limit service account permissions (RBAC)

### Code Review
- ✅ Require PR reviews before merge
- ✅ Enable branch protection on `main`
- ✅ Run security scans (Trivy)
- ✅ Review all changes to production overlays

### Access Control
- ✅ Limit who can approve production deployments
- ✅ Enable 2FA for all team members
- ✅ Audit workflow runs regularly
- ✅ Monitor failed authentication attempts

## 📈 Metrics & Reporting

### View Deployment History
```
GitHub → Actions → Filter by workflow → View all runs
```

### Success Rate
Monitor workflow success/failure rates in the Actions tab.

### Deployment Frequency
Track how often deployments occur to each environment.

## 🚨 Troubleshooting

### Issue: "KUBE_CONFIG secret not found"
**Solution:**
```bash
# Ensure secret name matches exactly:
KUBE_CONFIG_DEV
KUBE_CONFIG_QA
KUBE_CONFIG_PROD

# Check secret exists:
GitHub → Settings → Secrets → Actions
```

### Issue: "Validation failed"
**Solution:**
```bash
# Test locally first:
kubectl apply --dry-run=client -k overlays/dev/

# Check YAML syntax:
yamllint base/ overlays/
```

### Issue: "Deployment timeout"
**Solution:**
```bash
# Check cluster connectivity:
kubectl cluster-info

# Check ingress controller:
kubectl get pods -n ingress-nginx
```

### Issue: "Certificate not ready"
**Solution:**
```bash
# Check cert-manager:
kubectl get certificate
kubectl describe certificate ecombaker-tls-secret
kubectl logs -n cert-manager -l app=cert-manager
```

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [Kustomize Documentation](https://kustomize.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

## 🔄 Updating Workflows

To update workflows:

```bash
# 1. Edit workflow file
vim .github/workflows/deploy.yml

# 2. Test changes on feature branch
git checkout -b feature/update-workflow
git add .github/workflows/
git commit -m "Update deploy workflow"
git push origin feature/update-workflow

# 3. Create PR and test
# Workflow will run on PR to validate itself

# 4. Merge after testing
```

## 📞 Support

For workflow issues:
1. Check workflow logs in Actions tab
2. Review this documentation
3. Contact DevOps team
4. Create issue in this repository

---

**Last Updated:** December 21, 2025
