#!/bin/sh
set -eu

CONFIGURATION="${1:-debug}"
APP_NAME="CasprFlow"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
HASH_FILE="${CONTENTS_DIR}/.build_hash"

swift build -c "${CONFIGURATION}" >/dev/null
BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Track build binary hash to avoid re-signing when unchanged.
# Re-signing invalidates TCC (Accessibility) permissions each time.
BUILD_HASH=$(shasum -a 256 "${BIN_DIR}/${APP_NAME}" | cut -d' ' -f1)
SAVED_HASH=""
if [ -f "${HASH_FILE}" ]; then
    SAVED_HASH=$(cat "${HASH_FILE}")
fi

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CasprFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.casprflow.CasprFlow</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CasprFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>CasprFlow listens when you hold the hotkey.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>CasprFlow transcribes your command on-device.</string>
</dict>
</plist>
PLIST

if [ "${BUILD_HASH}" != "${SAVED_HASH}" ]; then
    cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
    /usr/bin/codesign --force --deep --sign - "${BUNDLE_DIR}" >/dev/null
    echo "${BUILD_HASH}" > "${HASH_FILE}"
    echo "Built ${BUNDLE_DIR} (re-signed — grant Accessibility again)"
else
    echo "Built ${BUNDLE_DIR} (signature preserved)"
fi
