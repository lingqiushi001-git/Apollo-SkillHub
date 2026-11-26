#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
APP_DIR="Apollo AgentHub.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

swiftc -O -module-cache-path /tmp/apolloagenthub-module-cache -framework AppKit -framework SwiftUI \
  Sources/Models.swift \
  Sources/Parsers.swift \
  Sources/SkillStore.swift \
  Sources/Modals.swift \
  Sources/Views.swift \
  Sources/main.swift \
  -o "$APP_DIR/Contents/MacOS/ApolloAgentHub"

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
echo "✅ Built Apollo AgentHub.app (v1.3.0)"
