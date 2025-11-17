#!/bin/bash

# Simple installation script for pre-built app (no Xcode required)
# Usage: ./install-app.sh

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}📦 Installing LidAngleSensor (Accordion Mode)${NC}"
echo ""

# Check if app exists in releases folder
if [ ! -f "releases/LidAngleSensor-accordion.zip" ]; then
    echo -e "${RED}❌ Error: releases/LidAngleSensor-accordion.zip not found${NC}"
    echo ""
    echo "   Please download it from:"
    echo "   https://github.com/restromingo/garm/releases"
    echo ""
    echo "   Or clone the repository:"
    echo "   git clone https://github.com/restromingo/garm.git"
    exit 1
fi

# Extract app
echo -e "${YELLOW}📂 Extracting app...${NC}"
cd releases
unzip -q -o LidAngleSensor-accordion.zip 2>/dev/null

if [ ! -d "LidAngleSensor.app" ]; then
    echo -e "${RED}❌ Error: Could not extract app${NC}"
    exit 1
fi

# Remove quarantine attributes (fixes "damaged" error)
echo -e "${YELLOW}🔓 Removing quarantine attributes...${NC}"
xattr -cr LidAngleSensor.app

# Remove old version if exists
if [ -d "/Applications/LidAngleSensor.app" ]; then
    echo -e "${YELLOW}🗑️  Removing old version...${NC}"
    rm -rf "/Applications/LidAngleSensor.app"
fi

# Copy to Applications
echo -e "${YELLOW}📂 Installing to /Applications...${NC}"
if cp -R LidAngleSensor.app /Applications/ 2>/dev/null; then
    echo -e "${GREEN}✅ Installation successful!${NC}"
elif sudo cp -R LidAngleSensor.app /Applications/ 2>&1; then
    echo -e "${GREEN}✅ Installation successful (with sudo)!${NC}"
else
    echo -e "${RED}❌ Installation failed${NC}"
    echo ""
    echo "   Please copy manually:"
    echo "   cp -R releases/LidAngleSensor.app /Applications/"
    exit 1
fi

# Cleanup
rm -rf LidAngleSensor.app
cd ..

echo ""
echo -e "${GREEN}🎹 LidAngleSensor installed successfully!${NC}"
echo ""
echo "   Launch from: /Applications/LidAngleSensor.app"
echo ""
echo "   If macOS says the app is 'damaged':"
echo "   xattr -cr /Applications/LidAngleSensor.app"
echo ""

