#!/usr/bin/env bash
# 打一个「未签名」的 ipa，用来交给 Sideloadly / AltStore 用你自己的 Apple ID 签
# 用法: bash scripts/make-ipa.sh
set -euo pipefail

cd "$(dirname "$0")/.."

rm -rf build/NovelReader.xcarchive build/Payload build/NovelReader-unsigned.ipa
mkdir -p build

xcodebuild archive \
  -project NovelReader.xcodeproj \
  -scheme NovelReader \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/NovelReader.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

APP="build/NovelReader.xcarchive/Products/Applications/NovelReader.app"
if [ ! -d "$APP" ]; then
  echo "没找到 $APP，archive 可能失败了，看看上面的日志。"
  exit 1
fi

mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry NovelReader-unsigned.ipa Payload)

echo
echo "==> build/NovelReader-unsigned.ipa"
echo "下一步：用 Sideloadly（Windows / macOS 都有）选这个 ipa，填你的 Apple ID 签进去。"
echo "注意：免费的 Apple ID 签出来 7 天过期、最多 3 个 App；付费开发者账号是一年。"
