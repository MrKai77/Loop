#!/bin/bash

echo "Settings build number!"

git=$(sh /etc/profile; which git)
number_of_commits=$("$git" rev-list HEAD --count)

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"

for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${number_of_commits}" "$plist"
  fi
done

settings_root_plist="$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Settings.bundle/Root.plist"

if [ -f "$settings_root_plist" ]; then
  settingsVersion="$APP_MARKETING_VERSION (${number_of_commits})"
  /usr/libexec/PlistBuddy -c "Set :PreferenceSpecifiers:1:DefaultValue $settingsVersion" "$settings_root_plist"
else
  echo "Could not find: $settings_root_plist"
  exit 0
fi