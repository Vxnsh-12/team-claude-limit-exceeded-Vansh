#!/usr/bin/env bash
# Local build & serve script for the VIT Quest Flutter super-app.
# Run this on YOUR machine (macOS / Windows WSL / x64 Linux) — the Emergent
# container that hosts this repo does not have a Flutter SDK.
#
#   cd flutter && bash serve_web.sh
#
# Then open http://localhost:3000 in your browser.

set -euo pipefail

echo "→ Flutter version"
flutter --version | head -1

echo "→ flutter clean"
flutter clean

echo "→ flutter pub get"
flutter pub get

echo "→ flutter build web (release)"
flutter build web --release

echo "→ Serving build/web on http://localhost:3000  (Ctrl+C to stop)"
python3 -m http.server 3000 --directory build/web
