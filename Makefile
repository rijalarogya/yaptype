.PHONY: open build test dmg

open:
	open Cadence.xcodeproj

build:
	xcodebuild -scheme Cadence -configuration Debug \
		-destination 'generic/platform=macOS' \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="-" \
		build

test:
	xcodebuild -scheme Cadence -configuration Debug \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="-" \
		test

dmg:
	./scripts/package-dmg.sh
