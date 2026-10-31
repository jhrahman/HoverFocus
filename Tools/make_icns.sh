#!/bin/zsh
# Regenerates Resources/AppIcon.icns from Tools/make_icon.swift
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d)
swiftc -o $T/mk Tools/make_icon.swift && $T/mk $T/icon.png
mkdir $T/AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s $T/icon.png --out $T/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) $T/icon.png --out $T/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $T/AppIcon.iconset -o Resources/AppIcon.icns
cp $T/icon.png Resources/AppIcon.png
