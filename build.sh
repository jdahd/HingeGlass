#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/HingeGlass.app/Contents/MacOS build/HingeGlass.app/Contents/Resources
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 Sources/LiveDesktop.swift Sources/Sensor.swift Sources/Renderer.swift Sources/main.swift -o build/HingeGlass.app/Contents/MacOS/HingeGlass -framework AppKit -framework MetalKit -framework ScreenCaptureKit -framework IOKit -framework Carbon
cp Info.plist build/HingeGlass.app/Contents/Info.plist
cp Resources/AppIcon.icns Resources/Credits.rtf build/HingeGlass.app/Contents/Resources/
cp ThirdPartyNotices/Macbook_Duo_Effect.txt build/HingeGlass.app/Contents/Resources/ThirdPartyNotices.txt
codesign --force --sign - --identifier local.jux.hingeglass build/HingeGlass.app
echo "Built: $PWD/build/HingeGlass.app"
