APP := build/Build/Products/Release/AudioDuck.app

.PHONY: project open build install clean icon

# Regenerate every time so added or removed source files are picked up.
project:
	xcodegen generate --quiet

open: project
	open AudioDuck.xcodeproj

build: project
	xcodebuild -project AudioDuck.xcodeproj -scheme AudioDuck -configuration Release \
		-destination 'generic/platform=macOS' -derivedDataPath build -quiet build

install: build
	pkill -x AudioDuck || true
	mkdir -p ~/Applications
	rm -rf ~/Applications/AudioDuck.app
	cp -R $(APP) ~/Applications/
	open ~/Applications/AudioDuck.app

clean:
	rm -rf build AudioDuck.xcodeproj

# Redraws the app icon from DuckShape.swift into the asset catalog.
icon:
	mkdir -p build
	swiftc -parse-as-library scripts/MakeIcon.swift Sources/AudioDuck/DuckShape.swift -o build/make-icon
	build/make-icon
