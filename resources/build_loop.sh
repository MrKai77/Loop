# Run this from the root directory of the repo:
# sh ./resources/build_loop.sh

echo "Preparing..."
rm -rf ./Loop.app

echo "Building Loop..."
xcodebuild clean archive -project ./Loop.xcodeproj -scheme Loop -archivePath ./Archive
xcodebuild -exportArchive -archivePath Archive.xcarchive -exportPath Release -exportOptionsPlist "resources/sparkle/export_options.plist"

echo "Moving Loop into current directory"
mv Release/*.app .

echo "Cleaning up..."
rm -rf Archive.xcarchive
rm -rf Release

open .
echo "Done!"
