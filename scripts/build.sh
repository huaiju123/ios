#!/usr/bin/env bash
# 编译到 iOS 模拟器（不签名，模拟器不需要）
# 用法: bash scripts/build.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "找不到 xcodebuild。"
  echo "这个工程用到了 SwiftUI / UIKit / AVFoundation，只能在 macOS + Xcode 上编译。"
  echo "Windows / Linux 上请改用 GitHub Actions（.github/workflows/ios-build.yml）。"
  exit 1
fi

xcodebuild \
  -project NovelReader.xcodeproj \
  -scheme NovelReader \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
