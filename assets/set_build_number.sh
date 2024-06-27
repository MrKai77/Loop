#!/bin/bash

echo "--- Setting build number! ---"

cd "$SRCROOT"

# Set VERSION
latest_tag=$(git describe --tags --abbrev=0 --exclude='prerelease')
sed -i -e "/VERSION =/ s/= .*/= $latest_tag/" Loop/Config.xcconfig

# Set BUILD_NUMBER
latest_commit_number=$(git rev-list --count HEAD)
sed -i -e "/BUILD_NUMBER =/ s/= .*/= $latest_commit_number/" Loop/Config.xcconfig

rm Loop/Config.xcconfig-e

echo "--- Done! ---"
