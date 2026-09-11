#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
mkdir -p releases
task_release_dir=$(mktemp -d "${TMPDIR%/}/hingeglass-release.XXXXXX")
trap 'rm -rf "$task_release_dir"' EXIT
mkdir "$task_release_dir/HingeGlass"
ditto build/HingeGlass.app "$task_release_dir/HingeGlass/HingeGlass.app"
cp README.md 使用说明.md ThirdPartyNotices/Macbook_Duo_Effect.txt "$task_release_dir/HingeGlass/"
ditto -c -k --sequesterRsrc --keepParent "$task_release_dir/HingeGlass" "releases/HingeGlass-${version}-macOS-arm64.zip"
unzip -tq "releases/HingeGlass-${version}-macOS-arm64.zip"
shasum -a 256 "releases/HingeGlass-${version}-macOS-arm64.zip" > "releases/HingeGlass-${version}-macOS-arm64.zip.sha256"
