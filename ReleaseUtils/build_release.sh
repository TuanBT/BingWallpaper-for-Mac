#!/bin/bash

# Script to build and package BingWallpaper for release
# This script creates a .pkg installer file for distribution

set -e  # Exit on error

echo "🚀 Starting BingWallpaper release build..."

# Get the project directory
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build
rm -f BingWallpaper.pkg
rm -f BingWallpaper.zip

# Check if Xcode is properly set up
if ! xcode-select -p &> /dev/null; then
    echo "❌ Error: Xcode command line tools not found"
    echo "Please install: xcode-select --install"
    exit 1
fi

# Check if we have full Xcode (not just Command Line Tools)
XCODE_PATH=$(xcode-select -p)
if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
    echo "❌ Error: Full Xcode is required (not just Command Line Tools)"
    echo ""
    echo "Please do one of the following:"
    echo "1. Install Xcode from App Store"
    echo "2. Then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "OR use the manual build process (see README)"
    exit 1
fi

# Build the app
echo "🔨 Building BingWallpaper..."
xcodebuild clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    -target BingWallpaperHelper \
    -target BingWallpaper \
    -configuration Release \
    BUILD_DIR="$PROJECT_DIR/build"

# Check if build succeeded
if [ ! -d "$PROJECT_DIR/build/Release/BingWallpaper.app" ]; then
    echo "❌ Error: Build failed - BingWallpaper.app not found"
    exit 1
fi

echo "✅ Build successful!"

# Create ZIP
echo "📦 Creating ZIP archive..."
cd "$PROJECT_DIR/build/Release/"
zip -r "$PROJECT_DIR/BingWallpaper.zip" ./BingWallpaper.app
echo "✅ Created: BingWallpaper.zip"

# Create PKG
echo "📦 Creating PKG installer..."
pkgbuild \
    --root "$PROJECT_DIR/build/Release/BingWallpaper.app" \
    --scripts "$PROJECT_DIR/ReleaseUtils" \
    --install-location /Applications/BingWallpaper.app \
    "$PROJECT_DIR/BingWallpaper.pkg"

if [ -f "$PROJECT_DIR/BingWallpaper.pkg" ]; then
    echo "✅ Created: BingWallpaper.pkg"
    echo ""
    echo "🎉 Release build complete!"
    echo ""
    echo "📝 Next steps:"
    echo "1. Create a git tag: git tag vx.x.x"
    echo "2. Push tag: git push origin vx.x.x"
    echo "3. Create GitHub release at: https://github.com/TuanBT/BingWallpaper-for-Mac/releases/new"
    echo "4. Upload BingWallpaper.pkg as release asset"
    echo ""
    echo "📂 Files created:"
    echo "   - $PROJECT_DIR/BingWallpaper.zip"
    echo "   - $PROJECT_DIR/BingWallpaper.pkg"
else
    echo "❌ Error: Failed to create PKG file"
    exit 1
fi
