#!/bin/bash

echo "--- Resetting build number! ---"

cd "$SRCROOT"

# Set VERSION
sed -i -e "/VERSION =/ s/= .*/= 0.0.0/" Loop/Config.xcconfig

# Set BUILD_NUMBER
sed -i -e "/BUILD_NUMBER =/ s/= .*/= 0/" Loop/Config.xcconfig

rm Loop/Config.xcconfig-e

echo "--- Done! ---"
