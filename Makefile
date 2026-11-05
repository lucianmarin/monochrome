APP_NAME = Monochrome
BUNDLE_DIR = $(APP_NAME).app
DERIVED_DATA = .build

.PHONY: build app run clean

build:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release -derivedDataPath $(DERIVED_DATA) build

app: build
	rm -rf "$(BUNDLE_DIR)"
	cp -R "$(DERIVED_DATA)/Build/Products/Release/$(BUNDLE_DIR)" "$(BUNDLE_DIR)"

run: app
	open "$(BUNDLE_DIR)"

clean:
	rm -rf "$(DERIVED_DATA)" "$(BUNDLE_DIR)"
