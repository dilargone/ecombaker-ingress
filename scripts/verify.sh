#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
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

print_header "Verifying Ingress Deployment for $ENV"

# Check ingress status
print_info "Checking ingress resource..."
if kubectl get ingress ecombaker-ingress &> /dev/null; then
    print_info "✅ Ingress resource exists"
    kubectl get ingress ecombaker-ingress
else
    print_error "❌ Ingress resource not found"
    exit 1
fi

echo ""

# Check TLS certificates
print_info "Checking TLS certificates..."
if [ "$ENV" == "prod" ]; then
    CERT_NAME="ecombaker-tls-secret"
elif [ "$ENV" == "qa" ]; then
    CERT_NAME="ecombaker-qa-tls-secret"
else
    CERT_NAME="ecombaker-dev-tls-secret"
fi

if kubectl get certificate $CERT_NAME &> /dev/null; then
    print_info "✅ Certificate resource exists: $CERT_NAME"
    CERT_STATUS=$(kubectl get certificate $CERT_NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$CERT_STATUS" == "True" ]; then
        print_info "✅ Certificate is ready"
    else
        print_warn "⚠️  Certificate is not ready yet"
        print_info "Certificate status:"
        kubectl get certificate $CERT_NAME
    fi
else
    print_warn "⚠️  Certificate resource not found (cert-manager will create it)"
fi

echo ""

# Check ingress controller
print_info "Checking NGINX ingress controller..."
if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
    READY_REPLICAS=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.replicas}')
    
    if [ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]; then
        print_info "✅ NGINX ingress controller is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
    else
        print_warn "⚠️  NGINX ingress controller: $READY_REPLICAS/$DESIRED_REPLICAS replicas ready"
    fi
else
    print_error "❌ NGINX ingress controller not found"
    exit 1
fi

echo ""

# Get external address
print_info "Getting ingress controller external address..."
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
EXTERNAL_HOSTNAME=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$EXTERNAL_IP" ]; then
    print_info "✅ External IP: $EXTERNAL_IP"
    INGRESS_ADDRESS="$EXTERNAL_IP"
elif [ -n "$EXTERNAL_HOSTNAME" ]; then
    print_info "✅ External hostname: $EXTERNAL_HOSTNAME"
    INGRESS_ADDRESS="$EXTERNAL_HOSTNAME"
else
    print_error "❌ Could not determine external address"
    exit 1
fi

echo ""

# Check backend services
print_info "Checking backend services..."
if [ "$ENV" == "prod" ]; then
    BACKEND_SVC="pilot-service"
    FRONTEND_SVC="pilot-frontend-service"
else
    BACKEND_SVC="pilot-service-$ENV"
    FRONTEND_SVC="pilot-frontend-service-$ENV"
fi

if kubectl get svc $BACKEND_SVC &> /dev/null; then
    print_info "✅ Backend service exists: $BACKEND_SVC"
else
    print_warn "⚠️  Backend service not found: $BACKEND_SVC"
fi

if kubectl get svc $FRONTEND_SVC &> /dev/null; then
    print_info "✅ Frontend service exists: $FRONTEND_SVC"
else
    print_warn "⚠️  Frontend service not found: $FRONTEND_SVC"
fi

echo ""

# Test connectivity
print_info "Testing connectivity..."

if [ "$ENV" == "prod" ]; then
    TEST_DOMAIN="store1.ecombaker.com"
else
    TEST_DOMAIN="store1.$ENV.ecombaker.com"
fi

print_info "Testing health endpoint..."
HTTP_CODE=$(curl -H "Host: $TEST_DOMAIN" -H "X-Tenant-Domain: $TEST_DOMAIN" \
    -k -s -o /dev/null -w "%{http_code}" \
    https://$INGRESS_ADDRESS/actuator/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ]; then
    print_info "✅ Health endpoint responding (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" == "000" ]; then
    print_warn "⚠️  Could not connect to health endpoint (network issue or DNS not configured)"
else
    print_warn "⚠️  Health endpoint returned HTTP $HTTP_CODE"
fi

echo ""

# Summary
print_header "Verification Summary"
echo ""
print_info "Environment: $ENV"
print_info "Ingress Address: $INGRESS_ADDRESS"
print_info "Test Domain: $TEST_DOMAIN"
echo ""
print_info "Test commands:"
echo ""
echo "  # Test API health endpoint"
echo "  curl -H \"Host: $TEST_DOMAIN\" -H \"X-Tenant-Domain: $TEST_DOMAIN\" https://$INGRESS_ADDRESS/actuator/health"
echo ""
echo "  # Test API authentication"
echo "  curl -X POST -H \"Host: $TEST_DOMAIN\" -H \"X-Tenant-Domain: $TEST_DOMAIN\" -H \"Content-Type: application/json\" https://$INGRESS_ADDRESS/api/user/auth"
echo ""
echo "  # Check certificate details"
echo "  kubectl describe certificate $CERT_NAME"
echo ""
echo "  # View ingress logs"
echo "  kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50"
echo ""

print_info "Verification complete! ✅"
