#!/bin/bash
# write-plist.sh <Info.plist path> <version> <build>
set -euo pipefail
cat > "$1" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>GranolaIsDead</string>
    <key>CFBundleIdentifier</key><string>com.muckstack.granolaisdead</string>
    <key>CFBundleName</key><string>GranolaIsDead</string>
    <key>CFBundleDisplayName</key><string>GranolaIsDead</string>
    <key>CFBundleShortVersionString</key><string>$2</string>
    <key>CFBundleVersion</key><string>$3</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.2</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GranolaIsDead transcribes what you say in meetings. Audio stays on this Mac.</string>
    <key>NSAudioCaptureUsageDescription</key>
    <string>GranolaIsDead transcribes the other side of your calls from your computer's audio, so no bot has to join. Audio stays on this Mac.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>GranolaIsDead shows your upcoming meetings and names your notes after them.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>GranolaIsDead shows your upcoming meetings and names your notes after them.</string>
    <key>SUFeedURL</key>
    <string>https://ihvfw4x5q9iy9zx1.public.blob.vercel-storage.com/granolaisdead-appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>L2iA4TR9JVW9eFDOazK7uS8p9n94TrNhX/9CgPjFbJs=</string>
    <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
PLIST
