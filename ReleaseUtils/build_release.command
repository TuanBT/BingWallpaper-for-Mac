#!/bin/bash

# Double-click this file on macOS to build BingWallpaper release
# It will open Terminal and run the build script automatically

# Navigate to the script's directory
cd "$(dirname "$0")"

echo "======================================"
echo "  BingWallpaper - Release Builder"
echo "======================================"
echo ""

# Run the build script
bash ./build_release.sh

echo ""
echo "======================================"
echo "  Build process finished!"
echo "======================================"
echo ""
echo "Press any key to close this window..."
read -n 1 -s
