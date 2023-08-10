# Run this from the root directory of the repo:
# sh ./resources/build_loop.sh

echo "Preparing..."
rm -rf ./Loop.app

echo "Building Loop..."
xcodebuild clean archive -project ./Loop.xcodeproj -scheme Loop -archivePath ./Archive

if [$1 -eq "debug"]; then
    echo "Debug Build!"
    xcodebuild -exportArchive -archivePath Archive.xcarchive -configuration Debug -exportPath Build -exportOptionsPlist "resources/sparkle/export_options.plist"
else
    echo "Release Build!"
    xcodebuild -exportArchive -archivePath Archive.xcarchive -configuration Release -exportPath Build -exportOptionsPlist "resources/sparkle/export_options.plist"
fi

echo "Moving Loop into current directory"
mv Build/*.app .

echo "Cleaning up..."
rm -rf Archive.xcarchive
rm -rf Build

open .
echo "Done!"
