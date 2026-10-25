#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

product=GrammarReview
app_name="Grammar Review"
bundle_id=com.grammarreview.app
app="$root/build/$app_name.app"
local_identity="Grammar Review Local Signing"
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  identity="$CODESIGN_IDENTITY"
elif security find-certificate -c "$local_identity" >/dev/null 2>&1; then
  identity="$local_identity"
else
  identity="-"
fi

if [[ -n "${VERSION:-}" && ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "VERSION must be one to three numbers separated by periods, such as 2026.1023.1435 (it's \"$VERSION\")" >&2
  exit 1
fi

public_key="$(printf '%s' "${SPARKLE_PUBLIC_KEY:-}" | tr -d '[:space:]')"
if [[ -n "$public_key" && "$(printf '%s' "$public_key" | base64 --decode 2>/dev/null | wc -c | tr -d ' ')" != 32 ]]; then
  echo "SPARKLE_PUBLIC_KEY isn't an EdDSA public key (32 bytes in base64, as generate_keys prints it)" >&2
  exit 1
fi

echo "==> Building $product (release)"
swift build -c release --product "$product"
bin_dir="$(swift build -c release --show-bin-path)"

echo "==> Assembling $app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin_dir/$product" "$app/Contents/MacOS/$product"
cp "$root/App/Info.plist" "$app/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$app/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$VERSION" "$app/Contents/Info.plist"
  echo "    Version $VERSION"
fi
if [[ -n "$public_key" ]]; then
  plutil -replace SUPublicEDKey -string "$public_key" "$app/Contents/Info.plist"
  echo "    Updates on: SUPublicEDKey from SPARKLE_PUBLIC_KEY"
else
  echo "    Updates off: no SPARKLE_PUBLIC_KEY"
fi
plutil -lint "$app/Contents/Info.plist" >/dev/null
printf 'APPL????' > "$app/Contents/PkgInfo"
if [[ -f "$root/App/AppIcon.icns" ]]; then
  cp "$root/App/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
else
  echo "    (no App/AppIcon.icns; run 'swift scripts/make-icon.swift' to create one)"
fi
ditto "$bin_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
shopt -s nullglob
for bundle in "$bin_dir"/*.bundle; do
  cp -R "$bundle" "$app/Contents/Resources/"
done
shopt -u nullglob

echo "==> Signing (identity: $identity)"
sign=(codesign --force --options runtime --sign "$identity")
if [[ "$identity" == "Developer ID Application"* ]]; then
  sign+=(--timestamp)
fi
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
"${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
"${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
"${sign[@]}" "$sparkle/Autoupdate"
"${sign[@]}" "$sparkle/Updater.app"
"${sign[@]}" "$app/Contents/Frameworks/Sparkle.framework"
if [[ "$identity" != "Developer ID Application"* ]]; then
  sign+=(--entitlements "$root/App/DisableLibraryValidation.entitlements")
fi
"${sign[@]}" "$app"
codesign --verify --deep --strict --verbose=1 "$app"

echo
echo "Built: $app"
if [[ "$identity" == "-" ]]; then
  cat <<EOF

Note: this build has an ad-hoc signature, which changes on every build, so macOS ignores
the Accessibility permission granted to an earlier build. Use "Reset Permission" in the setup
guide, or run:

    tccutil reset Accessibility $bundle_id

To keep the permission across rebuilds, create a local signing identity once:

    scripts/setup-signing.sh

(or set CODESIGN_IDENTITY to one of: security find-identity -v -p codesigning)
EOF
fi
