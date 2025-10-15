#!/bin/bash

# NetSpeedMonitor Build Script
# Builds the Swift Package and creates a proper macOS .app bundle

set -e  # Exit on any error

# Configuration
APP_NAME="NetSpeedMonitor"
BUNDLE_ID="com.r3js.netspeedmonitor"
BUILD_DIR=".build"
RELEASE_DIR="$BUILD_DIR/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup previous build
cleanup() {
    echo_info "Cleaning previous build artifacts..."
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
    fi
}

# Build the Swift executable
build_executable() {
    echo_info "Building Swift executable in release mode..."
    swift build -c release
    
    if [ ! -f "$RELEASE_DIR/$APP_NAME" ]; then
        echo_error "Build failed - executable not found at $RELEASE_DIR/$APP_NAME"
        exit 1
    fi
    
    echo_success "Swift executable built successfully"
}

# Create .app bundle structure
create_bundle_structure() {
    echo_info "Creating .app bundle structure..."
    
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"
    
    echo_success "Bundle structure created"
}

# Generate Info.plist with proper configuration
generate_info_plist() {
    echo_info "Generating Info.plist..."
    
    # Get version from git or use default
    VERSION=$(git describe --tags --always 2>/dev/null || echo "1.0.0")
    BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
    
    cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>NetSpeed Monitor</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSApplicationActivationPolicy</key>
    <string>accessory</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y) Carlos Guerrero. All rights reserved.</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
EOF
    
    echo_success "Info.plist generated with version $VERSION (build $BUILD_NUMBER)"
}

# Copy executable and set permissions
copy_executable() {
    echo_info "Copying executable to bundle..."
    
    cp "$RELEASE_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
    chmod +x "$MACOS_DIR/$APP_NAME"
    
    echo_success "Executable copied and made executable"
}

# Copy resources (icons, assets, etc.)
copy_resources() {
    echo_info "Copying resources..."
    
    # Copy Assets.xcassets if it exists and contains compiled assets
    if [ -d "NetSpeedMonitor/Assets.xcassets" ]; then
        # For now, just copy the xcassets directory
        # In a full Xcode build, this would be compiled to Assets.car
        cp -r "NetSpeedMonitor/Assets.xcassets" "$RESOURCES_DIR/"
        echo_success "Assets copied"
    else
        echo_warning "No Assets.xcassets found"
    fi
    
    # Copy entitlements to Resources (for reference)
    if [ -f "NetSpeedMonitor/NetSpeedMonitor.entitlements" ]; then
        cp "NetSpeedMonitor/NetSpeedMonitor.entitlements" "$RESOURCES_DIR/"
        echo_success "Entitlements copied"
    fi
}

# Code signing (optional)
sign_bundle() {
    local signing_identity=""
    
    # Check for available signing identities
    if command_exists security; then
        signing_identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n1 | sed -n 's/.*"\(.*\)".*/\1/p')
    fi
    
    if [ -n "$signing_identity" ]; then
        echo_info "Found signing identity: $signing_identity"
        echo_info "Signing the application bundle..."
        
        # Sign with entitlements
        if [ -f "$RESOURCES_DIR/NetSpeedMonitor.entitlements" ]; then
            codesign --force --options runtime --entitlements "$RESOURCES_DIR/NetSpeedMonitor.entitlements" --sign "$signing_identity" "$APP_DIR"
        else
            codesign --force --options runtime --sign "$signing_identity" "$APP_DIR"
        fi
        
        # Verify the signature
        if codesign --verify --verbose "$APP_DIR" 2>/dev/null; then
            echo_success "Application successfully signed"
        else
            echo_warning "Code signing verification failed"
        fi
    else
        echo_warning "No code signing identity found - app will not be signed"
        echo_warning "The app may show security warnings when distributed"
    fi
}

# Verify the bundle
verify_bundle() {
    echo_info "Verifying bundle structure..."
    
    # Check required files exist
    if [ ! -f "$CONTENTS_DIR/Info.plist" ]; then
        echo_error "Info.plist missing"
        exit 1
    fi
    
    if [ ! -f "$MACOS_DIR/$APP_NAME" ]; then
        echo_error "Executable missing"
        exit 1
    fi
    
    if [ ! -x "$MACOS_DIR/$APP_NAME" ]; then
        echo_error "Executable is not executable"
        exit 1
    fi
    
    echo_success "Bundle structure verified"
}

# Create distributable package
create_distributable() {
    echo_info "Creating distributable package..."
    
    local dist_dir="$BUILD_DIR/dist"
    mkdir -p "$dist_dir"
    
    # Copy the .app to dist directory
    cp -r "$APP_DIR" "$dist_dir/"
    
    # Create a ZIP archive for distribution
    local zip_name="$APP_NAME-$(git describe --tags --always 2>/dev/null || echo "latest").zip"
    cd "$dist_dir"
    zip -r "$zip_name" "$APP_NAME.app"
    cd - > /dev/null
    
    echo_success "Distributable created: $dist_dir/$zip_name"
    echo_info "App bundle location: $dist_dir/$APP_NAME.app"
}

# Show final instructions
show_instructions() {
    echo ""
    echo_success "Build completed successfully!"
    echo ""
    echo "📱 App Bundle: $BUILD_DIR/dist/$APP_NAME.app"
    echo "📦 Distribution: $BUILD_DIR/dist/$APP_NAME-*.zip"
    echo ""
    echo "To install:"
    echo "  1. Copy $APP_NAME.app to /Applications/"
    echo "  2. Or run: cp -r '$BUILD_DIR/dist/$APP_NAME.app' /Applications/"
    echo ""
    echo "To test the app:"
    echo "  open '$BUILD_DIR/dist/$APP_NAME.app'"
    echo ""
    echo "To distribute:"
    echo "  Share the .zip file from $BUILD_DIR/dist/"
}

# Main execution
main() {
    echo_info "Starting NetSpeedMonitor build process..."
    echo ""
    
    cleanup
    build_executable
    create_bundle_structure
    generate_info_plist
    copy_executable
    copy_resources
    sign_bundle
    verify_bundle
    create_distributable
    show_instructions
}

# Run main function
main "$@"