#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if environment is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <environment>"
    print_info "Available environments: dev, qa, prod"
    exit 1
fi

ENV=$1

# Validate environment
if [[ ! "$ENV" =~ ^(dev|qa|prod)$ ]]; then
    print_error "Invalid environment: $ENV"
    print_info "Available environments: dev, qa, prod"
    exit 1
fi

print_info "Deploying ingress for environment: $ENV"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if kustomize is installed (kubectl 1.14+ has built-in kustomize)
print_info "Checking kubectl version..."
kubectl version --client --short

# Check cluster connectivity
print_info "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_info "Please configure kubectl to connect to your cluster"
    exit 1
fi

print_info "Connected to cluster: $(kubectl config current-context)"

# Install cert-manager if not already installed
print_info "Checking if cert-manager is installed..."
if ! kubectl get namespace cert-manager &> /dev/null; then
    print_warn "cert-manager not found. Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    print_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    print_info "cert-manager installed successfully"
else
    print_info "cert-manager is already installed"
fi

# Check if NGINX ingress controller is installed
print_info "Checking if NGINX ingress controller is installed..."
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_warn "NGINX ingress controller not found. Installing..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    print_info "Waiting for NGINX ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s
    print_info "NGINX ingress controller installed successfully"
else
    print_info "NGINX ingress controller is already installed"
fi

# Apply cluster issuers first (if using base directly)
if [ "$ENV" == "prod" ]; then
    print_info "Applying cluster issuers..."
    kubectl apply -f base/cluster-issuer.yaml
fi

# Deploy using kustomize
print_info "Deploying ingress configuration..."
kubectl apply -k overlays/$ENV/

# Wait for ingress to be ready
print_info "Waiting for ingress to be created..."
sleep 5

# Get ingress details
print_info "Ingress deployed successfully!"
print_info ""
print_info "Ingress details:"
kubectl get ingress -o wide

# Get external IP/hostname
print_info ""
print_info "Getting ingress controller external address..."
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
EXTERNAL_HOSTNAME=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$EXTERNAL_IP" ]; then
    print_info "External IP: $EXTERNAL_IP"
    print_info ""
    print_info "Configure your DNS with:"
    if [ "$ENV" == "prod" ]; then
        print_info "  *.ecombaker.com      A    $EXTERNAL_IP"
        print_info "  ecombaker.com        A    $EXTERNAL_IP"
    else
        print_info "  *.$ENV.ecombaker.com A    $EXTERNAL_IP"
        print_info "  $ENV.ecombaker.com   A    $EXTERNAL_IP"
    fi
elif [ -n "$EXTERNAL_HOSTNAME" ]; then
    print_info "External hostname: $EXTERNAL_HOSTNAME"
    print_info ""
    print_info "Configure your DNS with:"
    if [ "$ENV" == "prod" ]; then
        print_info "  *.ecombaker.com      CNAME    $EXTERNAL_HOSTNAME"
        print_info "  ecombaker.com        CNAME    $EXTERNAL_HOSTNAME"
    else
        print_info "  *.$ENV.ecombaker.com CNAME    $EXTERNAL_HOSTNAME"
        print_info "  $ENV.ecombaker.com   CNAME    $EXTERNAL_HOSTNAME"
    fi
else
    print_warn "Could not determine external address"
    print_info "Run: kubectl get svc -n ingress-nginx ingress-nginx-controller"
fi

print_info ""
print_info "Deployment complete! 🎉"
print_info ""
print_info "Next steps:"
print_info "  1. Configure DNS records as shown above"
print_info "  2. Wait for SSL certificates to be issued (may take a few minutes)"
print_info "  3. Check certificate status: kubectl get certificate"
print_info "  4. Test your endpoints"
print_info ""
print_info "To verify deployment, run: ./scripts/verify.sh $ENV"
