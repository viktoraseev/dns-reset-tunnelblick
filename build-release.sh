#!/bin/zsh
set -euo pipefail

source_dir=${0:A:h}
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$source_dir/Info.plist")
dist_dir="$source_dir/dist"
mkdir -p "$dist_dir"

for arch in arm64 x86_64; do
  stage_dir="$dist_dir/$arch"
  app_dir="$stage_dir/Tunnelblick Reset.app"
  archive="$dist_dir/dns-reset-tunnelblick-v$version-macos-$arch.zip"
  rm -rf "$stage_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$source_dir/Info.plist" "$app_dir/Contents/Info.plist"
  cp "$source_dir/reset.sh" "$app_dir/Contents/Resources/reset.sh"
  cp -R "$source_dir/en.lproj" "$source_dir/ru.lproj" "$app_dir/Contents/Resources/"
  xcrun swiftc -O -target "$arch-apple-macosx13.0" -framework AppKit \
    "$source_dir/TunnelblickReset.swift" -o "$app_dir/Contents/MacOS/TunnelblickReset"
  /usr/bin/codesign --force --sign - "$app_dir"
  /usr/bin/codesign --verify --deep --strict "$app_dir"
  /usr/bin/ditto -c -k --norsrc --noextattr --noqtn --keepParent "$app_dir" "$archive"
  /usr/bin/shasum -a 256 "$archive"
done
