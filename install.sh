#!/bin/bash

# Installation script for LidAngleSensor with Accordion Mode
# Usage: ./install.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode is not installed.${NC}"
    echo "   Please install Xcode from the App Store: https://apps.apple.com/app/xcode/id497799835"
    echo "   Or install Command Line Tools: xcode-select --install"
    exit 1
fi

# Check Xcode license agreement
if ! xcodebuild -checkFirstLaunchStatus 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Xcode license agreement may need to be accepted.${NC}"
    echo "   Run: sudo xcodebuild -license accept"
fi

# Check if we're in the right directory
if [ ! -f "LidAngleSensor.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: Please run this script from the repository root directory${NC}"
    exit 1
fi

echo -e "${GREEN}🔨 Building application...${NC}"
echo "   This may take a few minutes on first build..."

# Build with visible output on first attempt
BUILD_OUTPUT=$(xcodebuild -project LidAngleSensor.xcodeproj \
           -scheme LidAngleSensor \
           -configuration Release \
           build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO 2>&1)

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Find the built app - try multiple methods
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app" -type d 2>/dev/null | grep Release | head -1)
    
    # Alternative: try to get path from build output
    if [ -z "$APP_PATH" ]; then
        APP_PATH=$(echo "$BUILD_OUTPUT" | grep -o "/Users/.*/LidAngleSensor.app" | head -1)
    fi
    
    # Last resort: try to find any LidAngleSensor.app
    if [ -z "$APP_PATH" ]; then
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app" -type d 2>/dev/null | head -1)
    fi
    
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}❌ Could not find the built application${NC}"
        echo ""
        echo "   The build may have succeeded but the app wasn't found."
        echo "   Try one of these alternatives:"
        echo ""
        echo "   1. Build manually with Xcode:"
        echo "      open LidAngleSensor.xcodeproj"
        echo "      Then: Product > Build (Cmd+B)"
        echo ""
        echo "   2. Check build output for errors:"
        echo "      xcodebuild -project LidAngleSensor.xcodeproj -scheme LidAngleSensor -configuration Release build"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}📦 Found application: $APP_PATH${NC}"
    echo -e "${YELLOW}📂 Copying to /Applications...${NC}"
    
    # Remove old app if it exists
    if [ -d "/Applications/LidAngleSensor.app" ]; then
        echo -e "${YELLOW}🗑️  Removing old version...${NC}"
        rm -rf "/Applications/LidAngleSensor.app"
    fi
    
    # Copy new app
    if cp -R "$APP_PATH" /Applications/ 2>/dev/null; then
        echo -e "${GREEN}✅ Application successfully installed to /Applications/LidAngleSensor.app${NC}"
        echo -e "${GREEN}🎹 Launch the app from the Applications folder!${NC}"
    else
        echo -e "${RED}❌ Error copying to /Applications. Trying with sudo...${NC}"
        if sudo cp -R "$APP_PATH" /Applications/; then
            echo -e "${GREEN}✅ Application successfully installed with sudo${NC}"
            echo -e "${GREEN}🎹 Launch the app from the Applications folder!${NC}"
        else
            echo -e "${RED}❌ Installation failed. Please copy manually:${NC}"
            echo "   cp -R \"$APP_PATH\" /Applications/"
            exit 1
        fi
    fi
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "   Common issues and solutions:"
    echo ""
    echo "   1. Xcode Command Line Tools not installed:"
    echo "      xcode-select --install"
    echo ""
    echo "   2. Xcode license not accepted:"
    echo "      sudo xcodebuild -license accept"
    echo ""
    echo "   3. Build manually to see detailed errors:"
    echo "      open LidAngleSensor.xcodeproj"
    echo "      Then: Product > Build (Cmd+B)"
    echo ""
    echo "   4. Check build output:"
    echo "      xcodebuild -project LidAngleSensor.xcodeproj -scheme LidAngleSensor -configuration Release build"
    echo ""
    exit 1
fi

