#!/usr/bin/env bash
# 编译并装到已启动的模拟器里跑起来
# 用法: bash scripts/run-sim.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.example.NovelReader"
APP="build/Build/Products/Debug-iphonesimulator/NovelReader.app"

bash scripts/build.sh

if ! xcrun simctl list devices booted | grep -q "Booted"; then
  echo "==> 没有启动中的模拟器，正在打开 Simulator…"
  open -a Simulator
  # 等模拟器起来，第一次启动会比较慢
  for _ in $(seq 1 30); do
    if xcrun simctl list devices booted | grep -q "Booted"; then break; fi
    sleep 2
  done
fi

if ! xcrun simctl list devices booted | grep -q "Booted"; then
  echo "模拟器没起来，请手动打开 Simulator 再执行一次。"
  exit 1
fi

xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

echo
echo "如果 bundle id 改过，记得同步改本脚本里的 BUNDLE_ID。"
echo "往模拟器里放书：把 epub / cbz 从 Finder 拖到模拟器窗口，会存进模拟器的「文件」App，"
echo "然后在 App 里点导入就能选到。"
