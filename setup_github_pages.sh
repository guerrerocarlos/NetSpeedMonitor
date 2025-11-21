#!/bin/bash

# GitHub Pages Setup Helper for NetSpeedMonitor

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

echo ""
echo_info "GitHub Pages Setup for NetSpeedMonitor"
echo ""

echo "📄 Files created in docs/ directory:"
echo "  ✓ index.html - Modern landing page"
echo "  ✓ .nojekyll - GitHub Pages configuration"
echo "  ✓ CNAME - Custom domain support (optional)"
echo "  ✓ README.md - Documentation"
echo ""

echo_info "To enable GitHub Pages:"
echo ""
echo "1. Go to: https://github.com/guerrerocarlos/NetSpeedMonitor/settings/pages"
echo ""
echo "2. Under 'Build and deployment':"
echo "   - Source: Deploy from a branch"
echo "   - Branch: master (or main)"
echo "   - Folder: /docs"
echo ""
echo "3. Click 'Save'"
echo ""

echo_success "Your site will be live at:"
echo "   🌐 https://guerrerocarlos.github.io/NetSpeedMonitor/"
echo ""

echo_info "Optional: Custom Domain"
echo "   If you have a custom domain, add it to docs/CNAME"
echo "   Then configure DNS with GitHub's IPs"
echo ""

echo "Opening GitHub Pages settings..."
sleep 2

# Try to open the settings page in the browser
if command -v open >/dev/null 2>&1; then
    open "https://github.com/guerrerocarlos/NetSpeedMonitor/settings/pages"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://github.com/guerrerocarlos/NetSpeedMonitor/settings/pages"
else
    echo "Please open this URL manually:"
    echo "https://github.com/guerrerocarlos/NetSpeedMonitor/settings/pages"
fi

echo ""
echo_success "Setup complete! 🎉"
