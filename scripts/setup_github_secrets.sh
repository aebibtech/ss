#!/bin/bash
# Script to configure GitHub Secrets for CI/CD using GitHub CLI (gh)
set -euo pipefail

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is not installed."
    echo "Please install it first: https://cli.github.com/"
    echo "On macOS, run: brew install gh"
    exit 1
fi

# Check if user is authenticated with gh
if ! gh auth status &> /dev/null; then
    echo "❌ Error: You are not authenticated with GitHub CLI."
    echo "Please run 'gh auth login' to authenticate."
    exit 1
fi

# Try to auto-detect repository name from git remote
REPO=""
if [ -d .git ] || git rev-parse --is-inside-work-tree &> /dev/null; then
    # Get remote origin URL and parse it to owner/repo format
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ $REMOTE_URL =~ github\.com[:/]([^/]+/[^.]+)(\.git)? ]]; then
        REPO="${BASH_REMATCH[1]}"
        echo "📂 Detected GitHub Repository: $REPO"
    fi
fi

if [ -z "$REPO" ]; then
    read -p "❓ Enter target GitHub repository (format: owner/repo): " REPO
fi

# Verify repo format
if [[ ! $REPO =~ ^[^/]+/[^/]+$ ]]; then
    echo "❌ Error: Invalid repository format. Please use 'owner/repo'."
    exit 1
fi

echo "===================================================="
echo "🔒 Configuring GitHub Secrets for $REPO"
echo "===================================================="
echo "You will be prompted to enter the value for each secret."
echo "Press Enter to skip/keep current value for any secret."
echo "===================================================="

set_secret() {
    local name=$1
    local description=$2
    local required=$3
    
    echo ""
    echo "🔑 Secret: $name"
    echo "   Description: $description"
    if [ "$required" = "true" ]; then
        echo "   (Status: REQUIRED)"
    else
        echo "   (Status: OPTIONAL)"
    fi
    
    # Read secret securely (hide input)
    read -rs -p "   Enter value: " value
    echo "" # Print newline after hidden input
    
    if [ -n "$value" ]; then
        echo "   Setting secret $name..."
        echo -n "$value" | gh secret set "$name" --repo "$REPO"
        echo "   ✅ Secret $name set successfully."
    else
        if [ "$required" = "true" ]; then
            echo "   ⚠️ Warning: Skipped a REQUIRED secret ($name)."
        else
            echo "   Skipped optional secret $name."
        fi
    fi
}

# 1. Required infrastructure secrets
set_secret "PULUMI_ACCESS_TOKEN" "Pulumi Cloud Access Token" "true"
set_secret "GCP_SA_KEY" "Google Cloud Service Account JSON Key" "true"
set_secret "CLOUDFLARE_API_TOKEN" "Cloudflare API Token (R2, Pages, DNS permissions)" "true"
set_secret "CLOUDFLARE_ACCOUNT_ID" "Cloudflare Account ID" "true"
set_secret "NEON_API_KEY" "Neon PostgreSQL Console API Key" "true"

# 2. Optional Android signing secrets
set_secret "ANDROID_KEYSTORE_BASE64" "Base64-encoded JKS Keystore file" "false"
set_secret "ANDROID_KEYSTORE_PASSWORD" "Android keystore password" "false"
set_secret "ANDROID_KEYSTORE_ALIAS" "Android keystore key alias" "false"
set_secret "ANDROID_KEY_PASSWORD" "Android keystore key password" "false"
set_secret "PLAY_SERVICE_ACCOUNT_JSON" "Google Play Console publisher service account JSON" "false"

echo ""
echo "===================================================="
echo "🎉 GitHub Secrets Configuration Completed!"
echo "===================================================="
