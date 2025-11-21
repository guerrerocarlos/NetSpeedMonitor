#!/bin/bash

# NetSpeedMonitor Homebrew Setup Script
# This script helps you set up the Homebrew tap repository

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
echo_info "NetSpeedMonitor Homebrew Setup"
echo ""

# Check if homebrew-tap repository exists
GITHUB_USER="guerrerocarlos"
TAP_REPO="homebrew-tap"
TAP_URL="https://github.com/$GITHUB_USER/$TAP_REPO"

echo_info "To make NetSpeedMonitor installable via Homebrew, follow these steps:"
echo ""

echo "1️⃣  Create a new GitHub repository called '$TAP_REPO'"
echo "   URL: https://github.com/new"
echo "   Repository name: $TAP_REPO"
echo "   (Make it public)"
echo ""

echo "2️⃣  Clone and setup the tap repository:"
echo "   git clone git@github.com:$GITHUB_USER/$TAP_REPO.git"
echo "   cd $TAP_REPO"
echo "   mkdir -p Casks"
echo "   cp \"$(pwd)/Casks/netspeedmonitor.rb\" Casks/"
echo "   git add Casks/netspeedmonitor.rb"
echo "   git commit -m \"Add NetSpeedMonitor cask\""
echo "   git push"
echo ""

echo "3️⃣  Create a release of NetSpeedMonitor:"
echo "   cd \"$(pwd)\""
echo "   git tag v1.0.0"
echo "   git push origin v1.0.0"
echo ""

echo "   The GitHub Action will automatically:"
echo "   • Build the app"
echo "   • Create a release with NetSpeedMonitor.zip"
echo "   • Calculate the SHA256 checksum"
echo ""

echo "4️⃣  Update the homebrew-tap with the SHA256:"
echo "   • Check the release notes for the SHA256 value"
echo "   • Update Casks/netspeedmonitor.rb in homebrew-tap:"
echo "     version \"1.0.0\""
echo "     sha256 \"<paste_sha256_here>\""
echo "   • Commit and push the changes"
echo ""

echo "5️⃣  Test the installation:"
echo "   brew tap $GITHUB_USER/tap"
echo "   brew install --cask netspeedmonitor"
echo ""

echo_success "Setup guide complete!"
echo ""
echo "For detailed instructions, see: HOMEBREW.md"
echo ""
