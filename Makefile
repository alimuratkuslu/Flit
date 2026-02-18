# Flit — Local build/release Makefile
# ─────────────────────────────────────────
# Prerequisites (developer machine):
#   xcode-select --install
#   xcrun notarytool store-credentials "FlitNotary" \
#       --apple-id YOUR_APPLE_ID \
#       --team-id  YOUR_TEAM_ID  \
#       --password YOUR_APP_SPECIFIC_PASSWORD
#
# Usage:
#   make build      — build Debug (quick sanity check)
#   make archive    — create a release archive in build/
#   make dmg        — package .app from archive into .dmg
#   make notarize   — submit .dmg to Apple Notary Service & staple
#   make release    — full pipeline: archive + dmg + notarize

# ── Variables ────────────────────────────────────────────────────────────────
SCHEME        := Flit
PROJECT       := Flit.xcodeproj
BUILD_DIR     := build
ARCHIVE       := $(BUILD_DIR)/Flit.xcarchive
EXPORT_DIR    := $(BUILD_DIR)/export
APP_PATH      := $(EXPORT_DIR)/Flit.app
VERSION       := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
                         Flit/Resources/Info.plist 2>/dev/null || echo "1.0.0")
DMG_NAME      := Flit-$(VERSION).dmg
DMG_PATH      := $(BUILD_DIR)/$(DMG_NAME)
NOTARY_PROFILE := FlitNotary   # name used in `xcrun notarytool store-credentials`

# ── Targets ──────────────────────────────────────────────────────────────────

.PHONY: build archive dmg notarize release clean help

help:
	@echo "Flit build targets:"
	@echo "  build      Build Debug (quick check)"
	@echo "  archive    Create release archive"
	@echo "  dmg        Export .app and package into DMG"
	@echo "  notarize   Submit DMG to Apple + staple"
	@echo "  release    Full pipeline: archive → dmg → notarize"
	@echo "  clean      Remove build/ directory"

build:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme  $(SCHEME) \
	  -configuration Debug \
	  build | xcpretty || xcodebuild \
	  -project $(PROJECT) \
	  -scheme  $(SCHEME) \
	  -configuration Debug \
	  build

archive: $(BUILD_DIR)
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme  $(SCHEME) \
	  -configuration Release \
	  -archivePath $(ARCHIVE) \
	  archive
	@echo "Archive created at $(ARCHIVE)"

dmg: archive
	# Export .app from archive using ExportOptions.plist
	xcodebuild \
	  -exportArchive \
	  -archivePath   $(ARCHIVE) \
	  -exportPath    $(EXPORT_DIR) \
	  -exportOptionsPlist ExportOptions.plist
	@echo "Exported app to $(APP_PATH)"

	# Build DMG
	hdiutil create \
	  -volname "Flit $(VERSION)" \
	  -srcfolder $(APP_PATH) \
	  -ov \
	  -format UDZO \
	  $(DMG_PATH)
	@echo "DMG created: $(DMG_PATH)"
	@echo "SHA256: $$(shasum -a 256 $(DMG_PATH) | awk '{print $$1}')"

notarize: $(DMG_PATH)
	@echo "Submitting $(DMG_PATH) for notarization…"
	xcrun notarytool submit $(DMG_PATH) \
	  --keychain-profile "$(NOTARY_PROFILE)" \
	  --wait
	@echo "Stapling notarization ticket…"
	xcrun stapler staple $(DMG_PATH)
	@echo "Notarization complete."

release: dmg notarize
	@echo "Release ready: $(DMG_PATH)"
	@echo "SHA256: $$(shasum -a 256 $(DMG_PATH) | awk '{print $$1}')"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
