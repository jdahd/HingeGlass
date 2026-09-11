#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
task_icon_dir=$(mktemp -d "${TMPDIR%/}/hingeglass-icon.XXXXXX")
trap 'rm -rf "$task_icon_dir"' EXIT
mkdir "$task_icon_dir/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png --out "$task_icon_dir/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  twice=$((size * 2))
  sips -z "$twice" "$twice" Resources/AppIcon.png --out "$task_icon_dir/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$task_icon_dir/AppIcon.iconset" -o Resources/AppIcon.icns
