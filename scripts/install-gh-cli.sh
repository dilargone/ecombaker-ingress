#!/bin/bash

# Quick installer for GitHub CLI on macOS

set -e

echo "========================================="
echo "Installing GitHub CLI (gh)"
echo "========================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed."
    echo ""
    echo "Please install Homebrew first:"
    echo "Visit: https://brew.sh/"
    echo ""
    exit 1
fi

echo "Installing GitHub CLI via Homebrew..."
brew install gh

echo ""
echo "✅ GitHub CLI installed successfully!"
echo ""
echo "Next steps:"
echo "1. Authenticate: gh auth login"
echo "2. Run trigger script: ./scripts/trigger-github-action.sh"
echo ""
