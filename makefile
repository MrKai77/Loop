release:
	set -o pipefail && xcodebuild archive \
		-project ./Loop.xcodeproj \
		-destination "generic/platform=macOS" \
		-scheme "Loop" \
		-archivePath "./Build/Loop.xcarchive" \
		-xcconfig "./Loop/Config.xcconfig" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY= \
		CODE_SIGN_ENTITLEMENTS= \
		GCC_OPTIMIZATION_LEVEL=s \
		SWIFT_OPTIMIZATION_LEVEL=-O \
		GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym | xcbeautify
	create-dmg \
		--volname "Loop" \
		--background "./assets/graphics/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 160 \
		--icon "Loop.app" 180 170 \
		--hide-extension "Loop.app" \
		--app-drop-link 480 170 \
		--no-internet-enable \
		"./Build/Loop.dmg" \
		"./Build/Loop.xcarchive/Products/Applications/"
	cp -R ./Build/Loop.xcarchive/Products/Applications/ ./Build/
	ditto -c -k --sequesterRsrc --keepParent ./Build/Loop.app ./Build/Loop.zip

debug:
	set -o pipefail && xcodebuild archive \
		-project ./Loop.xcodeproj \
		-destination "generic/platform=macOS" \
		-scheme "Loop" \
		-configuration Debug \
		-archivePath "./Build/Loop.xcarchive" \
		-xcconfig "./Loop/Config.xcconfig" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY= \
		CODE_SIGN_ENTITLEMENTS= \
		GCC_OPTIMIZATION_LEVEL=s \
		SWIFT_OPTIMIZATION_LEVEL=-O \
		GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym | xcbeautify
	create-dmg \
		--volname "Loop" \
		--background "./assets/graphics/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 160 \
		--icon "Loop.app" 180 170 \
		--hide-extension "Loop.app" \
		--app-drop-link 480 170 \
		--no-internet-enable \
		"./Build/Loop.dmg" \
		"./Build/Loop.xcarchive/Products/Applications/"
	cp -R ./Build/Loop.xcarchive/Products/Applications/ ./Build/
	ditto -c -k --sequesterRsrc --keepParent ./Build/Loop.app ./Build/Loop.zip

app-standalone:
	set -o pipefail && xcodebuild archive \
		-project ./Loop.xcodeproj \
		-destination "generic/platform=macOS" \
		-scheme "Loop" \
		-archivePath "./Build/Loop.xcarchive" \
		-xcconfig "./Loop/Config.xcconfig" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY= \
		CODE_SIGN_ENTITLEMENTS= \
		GCC_OPTIMIZATION_LEVEL=s \
		SWIFT_OPTIMIZATION_LEVEL=-O \
		GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym | xcbeautify
	cp -R ./Build/Loop.xcarchive/Products/Applications/ ./Build/
