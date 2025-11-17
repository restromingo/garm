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
    echo -e "${RED}❌ Xcode is not installed. Please install Xcode from the App Store.${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "LidAngleSensor.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: Please run this script from the repository root directory${NC}"
    exit 1
fi

echo -e "${GREEN}🔨 Building application...${NC}"
xcodebuild -project LidAngleSensor.xcodeproj \
           -scheme LidAngleSensor \
           -configuration Release \
           build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Find the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app" -type d 2>/dev/null | grep Release | head -1)
    
    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}❌ Could not find the built application${NC}"
        echo "   Try building manually with Xcode or check the build output above"
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
    echo -e "${RED}❌ Build failed. Please check the error messages above.${NC}"
    echo "   Make sure Xcode is properly installed and the project can be built."
    exit 1
fi

