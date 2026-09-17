.PHONY: open build test dmg

XCODEBUILD ?= /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

open:
	open Yaptype.xcodeproj

build:
	$(XCODEBUILD) -scheme Yaptype -project Yaptype.xcodeproj -configuration Debug \
		-destination 'generic/platform=macOS' \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="-" \
		build

test:
	$(XCODEBUILD) -scheme Yaptype -project Yaptype.xcodeproj -configuration Debug \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="-" \
		test

dmg:
	./scripts/package-dmg.sh
