APP_NAME    := MacBright
BUILD_DIR   := .build
CONFIG      := release
BIN_PATH    := $(BUILD_DIR)/$(CONFIG)/$(APP_NAME)
APP_BUNDLE  := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents
MACOS_DIR   := $(CONTENTS)/MacOS
RES_DIR     := $(CONTENTS)/Resources

.PHONY: all build app sign zip run clean

all: app

build:
	swift build -c $(CONFIG)

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS_DIR) $(RES_DIR)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp $(BIN_PATH) $(MACOS_DIR)/$(APP_NAME)
	@echo "Built $(APP_BUNDLE)"

# Ad-hoc sign so Gatekeeper recognises the bundle as a coherent app.
# Doesn't make it "trusted" — users still need to clear the quarantine
# attribute on first launch (see README).
sign: app
	codesign --force --deep --sign - $(APP_BUNDLE)
	codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)

# Produce a release-ready zip suitable for upload to GitHub Releases.
zip: sign
	cd $(BUILD_DIR) && ditto -c -k --sequesterRsrc --keepParent $(APP_NAME).app $(APP_NAME).zip
	@echo "Built $(BUILD_DIR)/$(APP_NAME).zip"

run: app
	open $(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(BUILD_DIR)/$(APP_NAME).app $(BUILD_DIR)/$(APP_NAME).zip
