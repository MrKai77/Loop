#!/bin/bash

echo "--- Setting build number! ---"

cd "$SRCROOT"

sed -i -e "/BUILD_NUMBER =/ s/= .*/= $(git rev-list --count HEAD)/" Loop/Config.xcconfig

rm Loop/Config.xcconfig-e

echo "--- Done! ---"
