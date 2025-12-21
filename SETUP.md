# Setup Instructions

## Creating a Separate Repository

### Step 1: Create the New Repository on GitHub

1. Go to GitHub and create a new repository named `ecombaker-ingress`
2. Don't initialize it with README, .gitignore, or license (we'll push existing files)

### Step 2: Initialize Git in the Ingress Directory

```bash
cd /Users/dila.gurung.1987/IdeaProjects/store-pilot/ecombaker-ingress-repo

# Initialize git
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: Kubernetes ingress configuration for Ecombaker platform"
```

### Step 3: Connect to Remote Repository

```bash
# Add remote (replace with your actual repository URL)
git remote add origin git@github.com:dilargone/ecombaker-ingress.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 4: Make Scripts Executable

```bash
chmod +x scripts/deploy.sh
chmod +x scripts/verify.sh
git add scripts/
git commit -m "Make scripts executable"
git push
```

## Moving to Separate Location (Outside store-pilot)

If you want to move this to a completely separate directory:

```bash
# From your projects directory
cd /Users/dila.gurung.1987/IdeaProjects/

# Copy the entire directory
cp -r store-pilot/ecombaker-ingress-repo ./ecombaker-ingress

# Navigate to new directory
cd ecombaker-ingress

# Initialize as new repository
git init
git add .
git commit -m "Initial commit: Kubernetes ingress configuration"
git remote add origin git@github.com:dilargone/ecombaker-ingress.git
git branch -M main
git push -u origin main
```

## Initial Setup After Cloning

When team members clone this repository for the first time:

```bash
# Clone the repository
git clone git@github.com:dilargone/ecombaker-ingress.git
cd ecombaker-ingress

# Make scripts executable
chmod +x scripts/*.sh

# Configure kubectl to connect to your cluster
# (specific to your cloud provider)

# Deploy to desired environment
./scripts/deploy.sh dev
```

## Configuration Updates

### Updating Email for Let's Encrypt

Edit `base/cluster-issuer.yaml` and change:
```yaml
email: devops@ecombaker.com  # Change to your actual email
```

### Updating Service Names

If your Kubernetes service names are different, update:
- `base/ingress.yaml` - for production services
- `overlays/dev/ingress-patch.yaml` - for dev services
- `overlays/qa/ingress-patch.yaml` - for QA services

### Updating Domain Names

If your domain is different from `ecombaker.com`, update all YAML files with your actual domain.

## Integrating with CI/CD

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Ingress

on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - qa
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}
      
      - name: Deploy ingress
        run: |
          ENV=${{ github.event.inputs.environment || 'dev' }}
          ./scripts/deploy.sh $ENV
      
      - name: Verify deployment
        run: |
          ENV=${{ github.event.inputs.environment || 'dev' }}
          ./scripts/verify.sh $ENV
```

### GitLab CI Example

Create `.gitlab-ci.yml`:

```yaml
stages:
  - deploy
  - verify

.deploy_template:
  stage: deploy
  image: bitnami/kubectl:latest
  before_script:
    - mkdir -p ~/.kube
    - echo "$KUBE_CONFIG" | base64 -d > ~/.kube/config
    - chmod +x scripts/*.sh
  script:
    - ./scripts/deploy.sh $ENVIRONMENT

deploy_dev:
  extends: .deploy_template
  variables:
    ENVIRONMENT: dev
  only:
    - develop

deploy_qa:
  extends: .deploy_template
  variables:
    ENVIRONMENT: qa
  only:
    - staging

deploy_prod:
  extends: .deploy_template
  variables:
    ENVIRONMENT: prod
  only:
    - main
  when: manual
```

## Security Best Practices

1. **Never commit kubeconfig files or secrets to git**
2. Store sensitive data in Kubernetes secrets, not in YAML files
3. Use separate namespaces for each environment
4. Implement RBAC policies
5. Use network policies to restrict traffic
6. Enable audit logging in your cluster

## Maintenance

### Updating NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml
```

### Updating Cert-Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

### Certificate Renewal

Cert-manager automatically renews certificates. To force renewal:

```bash
kubectl delete certificate ecombaker-tls-secret
kubectl apply -k overlays/prod/
```

## Support

For issues:
1. Check logs: `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx`
2. Review ingress status: `kubectl describe ingress ecombaker-ingress`
3. Check certificate status: `kubectl get certificate`
4. Open an issue in this repository

## License

Proprietary - Ecombaker Platform
