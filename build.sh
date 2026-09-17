#!/bin/zsh
set -e

source_dir=${0:A:h}
app_dir="$HOME/Applications/Tunnelblick Reset.app"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$source_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$source_dir/reset.sh" "$app_dir/Contents/Resources/reset.sh"
cp -R "$source_dir/en.lproj" "$source_dir/ru.lproj" "$app_dir/Contents/Resources/"
xcrun swiftc -O -framework AppKit "$source_dir/TunnelblickReset.swift" -o "$app_dir/Contents/MacOS/TunnelblickReset"
codesign --force --sign - "$app_dir"

echo "Built $app_dir"
