APP := build/Build/Products/Release/AudioPriorities.app

.PHONY: project open build install clean

# Regenerate every time so added or removed source files are picked up.
project:
	xcodegen generate --quiet

open: project
	open AudioPriorities.xcodeproj

build: project
	xcodebuild -project AudioPriorities.xcodeproj -scheme AudioPriorities -configuration Release \
		-destination 'generic/platform=macOS' -derivedDataPath build -quiet build

install: build
	-pkill -x AudioPriorities
	mkdir -p ~/Applications
	rm -rf ~/Applications/AudioPriorities.app
	cp -R $(APP) ~/Applications/
	open ~/Applications/AudioPriorities.app

clean:
	rm -rf build AudioPriorities.xcodeproj
