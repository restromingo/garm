#!/bin/bash

# Script to create a release archive
# Usage: ./create-release.sh

set -u

echo "🔨 Building application..."
xcodebuild -project LidAngleSensor.xcodeproj \
           -scheme LidAngleSensor \
           -configuration Release \
           build \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LidAngleSensor.app" -type d 2>/dev/null | grep Release | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Could not find the built application"
    exit 1
fi

# Create releases directory
mkdir -p releases

# Copy app
echo "📦 Copying app to releases folder..."
rm -rf releases/LidAngleSensor.app
cp -R "$APP_PATH" releases/

# Sign app with ad-hoc signature (no quarantine needed)
echo "✍️  Signing app with ad-hoc signature..."
codesign --force --deep --sign - releases/LidAngleSensor.app

# Create zip archive
echo "📦 Creating zip archive..."
cd releases
rm -f LidAngleSensor-accordion.zip
zip -r LidAngleSensor-accordion.zip LidAngleSensor.app > /dev/null
cd ..

echo "✅ Release archive created: releases/LidAngleSensor-accordion.zip"
echo ""
echo "To create a GitHub release:"
echo "1. Go to https://github.com/restromingo/garm/releases/new"
echo "2. Upload releases/LidAngleSensor-accordion.zip"
echo "3. Add release notes"

