#!/bin/bash

# GitHub Actions Trigger Tool
# This script allows you to trigger GitHub Actions workflows from your local machine

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="dilargone/ecombaker-ingress"  # Change this to your repo

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Actions Trigger Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}GitHub CLI (gh) is not installed.${NC}"
    echo ""
    echo "To install GitHub CLI on macOS:"
    echo -e "${GREEN}brew install gh${NC}"
    echo ""
    echo "Or visit: https://cli.github.com/"
    echo ""
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}You need to authenticate with GitHub.${NC}"
    echo ""
    echo "Run: ${GREEN}gh auth login${NC}"
    echo ""
    exit 1
fi

# Function to trigger workflow
trigger_workflow() {
    local workflow=$1
    local env=$2
    
    echo -e "${BLUE}Triggering workflow: ${workflow}${NC}"
    echo -e "${BLUE}Environment: ${env}${NC}"
    echo ""
    
    if gh workflow run "$workflow" --repo "$REPO" -f environment="$env"; then
        echo -e "${GREEN}✅ Workflow triggered successfully!${NC}"
        echo ""
        echo "View the workflow run:"
        echo -e "${GREEN}gh run list --workflow=$workflow --repo $REPO${NC}"
        echo ""
        echo "Watch the workflow:"
        echo -e "${GREEN}gh run watch --repo $REPO${NC}"
    else
        echo -e "${RED}❌ Failed to trigger workflow${NC}"
        exit 1
    fi
}

# Show menu
echo "Available workflows:"
echo "1) Deploy Ingress (deploy.yml)"
echo "2) Run Health Check (health-check.yml)"
echo "3) View Recent Runs"
echo "4) Watch Latest Run"
echo ""
read -p "Select option (1-4): " option

case $option in
    1)
        echo ""
        echo "Select environment:"
        echo "1) Development"
        echo "2) QA"
        echo "3) Production"
        echo ""
        read -p "Select environment (1-3): " env_option
        
        case $env_option in
            1) trigger_workflow "deploy.yml" "development" ;;
            2) trigger_workflow "deploy.yml" "qa" ;;
            3) trigger_workflow "deploy.yml" "production" ;;
            *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
        esac
        ;;
    2)
        echo ""
        echo "Select environment:"
        echo "1) Development"
        echo "2) QA"
        echo "3) Production"
        echo ""
        read -p "Select environment (1-3): " env_option
        
        case $env_option in
            1) trigger_workflow "health-check.yml" "development" ;;
            2) trigger_workflow "health-check.yml" "qa" ;;
            3) trigger_workflow "health-check.yml" "production" ;;
            *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
        esac
        ;;
    3)
        echo ""
        gh run list --repo "$REPO" --limit 10
        ;;
    4)
        echo ""
        echo -e "${BLUE}Watching latest workflow run...${NC}"
        gh run watch --repo "$REPO"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac
