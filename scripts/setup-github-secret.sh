#!/bin/bash

# GitHub Secrets Setup Helper
# This script helps you prepare kubeconfig for GitHub Actions secrets

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Secrets Setup Helper${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Not connected to any Kubernetes cluster${NC}"
    echo "Run: kubectl config use-context <context-name>"
    exit 1
fi

# Show current context
CURRENT_CONTEXT=$(kubectl config current-context)
echo -e "${GREEN}✅ Connected to cluster${NC}"
echo "Current context: ${BLUE}$CURRENT_CONTEXT${NC}"
echo ""

# Ask which environment
echo "Which environment is this cluster for?"
echo "1) Development (DEV)"
echo "2) QA"
echo "3) Production (PROD)"
echo ""
read -p "Select (1-3): " env_choice

case $env_choice in
    1) ENV="DEV"; SECRET_NAME="KUBE_CONFIG_DEV" ;;
    2) ENV="QA"; SECRET_NAME="KUBE_CONFIG_QA" ;;
    3) ENV="PROD"; SECRET_NAME="KUBE_CONFIG_PROD" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

echo ""
echo -e "${BLUE}Preparing kubeconfig for: ${ENV}${NC}"
echo ""

# Export kubeconfig
TEMP_FILE="/tmp/kubeconfig-${ENV}.yaml"
BASE64_FILE="/tmp/kubeconfig-${ENV}-base64.txt"

echo "Exporting kubeconfig..."
kubectl config view --minify --flatten > "$TEMP_FILE"

# Encode to base64
echo "Encoding to base64..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    cat "$TEMP_FILE" | base64 | tr -d '\n' > "$BASE64_FILE"
else
    # Linux
    cat "$TEMP_FILE" | base64 -w 0 > "$BASE64_FILE"
fi

echo ""
echo -e "${GREEN}✅ Success!${NC}"
echo ""
echo "Base64-encoded kubeconfig saved to:"
echo -e "${YELLOW}$BASE64_FILE${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps:${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. Go to GitHub repository settings:"
echo -e "   ${YELLOW}https://github.com/dilargone/ecombaker-ingress/settings/secrets/actions${NC}"
echo ""
echo "2. Click: ${GREEN}New repository secret${NC}"
echo ""
echo "3. Name: ${GREEN}${SECRET_NAME}${NC}"
echo ""
echo "4. Value: Copy and paste the content from:"
echo -e "   ${YELLOW}$BASE64_FILE${NC}"
echo ""
echo "   You can copy it with:"
echo -e "   ${GREEN}cat $BASE64_FILE | pbcopy${NC}  (copies to clipboard)"
echo ""
echo "5. Click ${GREEN}Add secret${NC}"
echo ""
echo -e "${YELLOW}⚠️  Security reminder:${NC}"
echo "   - Don't share this file"
echo "   - Don't commit it to Git"
echo "   - Delete it after adding to GitHub"
echo ""

# Ask if user wants to copy to clipboard (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    read -p "Copy to clipboard now? (y/n): " copy_choice
    if [[ "$copy_choice" == "y" || "$copy_choice" == "Y" ]]; then
        cat "$BASE64_FILE" | pbcopy
        echo -e "${GREEN}✅ Copied to clipboard!${NC}"
        echo ""
        echo "Now go to GitHub and paste it as secret: ${GREEN}${SECRET_NAME}${NC}"
    fi
fi

echo ""
echo "Clean up temp files:"
echo -e "${YELLOW}rm $TEMP_FILE $BASE64_FILE${NC}"
echo ""
