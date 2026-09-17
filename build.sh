#!/bin/zsh
set -e

source_dir=${0:A:h}
app_dir="$HOME/Applications/DNS Reset.app"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$source_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$source_dir/reset.sh" "$app_dir/Contents/Resources/reset.sh"
xcrun swiftc -O -framework AppKit "$source_dir/DNSReset.swift" -o "$app_dir/Contents/MacOS/DNSReset"
codesign --force --sign - "$app_dir"

echo "Built $app_dir"
