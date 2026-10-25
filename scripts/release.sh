#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Builds a release of Grammar Review and packages it in build/release/ as
Grammar-Review-<version>.zip and .dmg, plus release.json, which describes them for the website
and the update feed (scripts/assemble-site.py reads it from the GitHub release).

The version is the current date and time in UTC, YYYY.MMDD.HHMM (2026.1023.1435 for 14:35 on
23 October 2026), for both CFBundleShortVersionString and CFBundleVersion, so every release is
newer than the last for Sparkle. VERSION=1.2.3 picks another version.

By default the release is signed with a Developer ID, notarized by Apple and stapled, so it opens
without warnings on other Macs:

  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  NOTARY_PROFILE=grammar-review scripts/release.sh

Once per Mac, store the notarization credentials in the keychain under that profile name:

  xcrun notarytool store-credentials grammar-review \
    --apple-id you@example.com --team-id TEAMID --password <app-specific password>

NOTARY_KEYCHAIN names the keychain holding that profile when it isn't the login keychain (CI).

Updates: SPARKLE_PUBLIC_KEY goes into the app (see scripts/build-app.sh), and SPARKLE_PRIVATE_KEY,
the matching private key (exported with Sparkle's `generate_keys -x`), signs the zip so Sparkle
can offer it as an update. Without the private key the release isn't offered as an update.

Options:
  --ad-hoc          without a Developer ID: ad-hoc signed and not notarized. macOS asks for
                    confirmation before opening it the first time.
  --skip-notarize   sign with the Developer ID but don't notarize (for trying out the packaging;
                    Gatekeeper will still warn on other Macs)
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

ad_hoc=0
notarize=1
for arg in "$@"; do
  case "$arg" in
    --ad-hoc)
      ad_hoc=1
      notarize=0
      ;;
    --skip-notarize) notarize=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (see --help)" >&2
      exit 64
      ;;
  esac
done

fail() {
  echo "release: $*" >&2
  exit 1
}

if ((ad_hoc)); then
  export CODESIGN_IDENTITY="-"
else
  [[ "${CODESIGN_IDENTITY:-}" == "Developer ID Application"* ]] \
    || fail "set CODESIGN_IDENTITY to a \"Developer ID Application: …\" identity (security find-identity -v -p codesigning), or pass --ad-hoc"
  security find-identity -v -p codesigning | grep -qF "$CODESIGN_IDENTITY" \
    || fail "the identity \"$CODESIGN_IDENTITY\" isn't in the keychain"
fi
if ((notarize)); then
  [[ -n "${NOTARY_PROFILE:-}" ]] || fail "set NOTARY_PROFILE to a notarytool keychain profile (see the top of this script), or pass --skip-notarize"
fi
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" && -z "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  fail "SPARKLE_PRIVATE_KEY is set but SPARKLE_PUBLIC_KEY isn't; the app needs the public key to accept updates"
fi

notary=(--keychain-profile "${NOTARY_PROFILE:-}")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then
  notary+=(--keychain "$NOTARY_KEYCHAIN")
fi

export VERSION="${VERSION:-$(date -u +%Y.%m%d.%H%M)}"
app_name="Grammar Review"
app="$root/build/$app_name.app"

scripts/build-app.sh
plist="$app/Contents/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"
out="$root/build/release"
base="$out/Grammar-Review-$version"
metadata="$out/release.json"
mkdir -p "$out"
rm -f "$base.zip" "$base.dmg" "$metadata"

if ((notarize)); then
  echo "==> Notarizing (this usually takes a few minutes)"
  submission="$out/notarize.zip"
  ditto -c -k --keepParent "$app" "$submission"
  xcrun notarytool submit "$submission" "${notary[@]}" --wait
  rm -f "$submission"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=2 "$app"
fi

echo "==> Packaging"
ditto -c -k --sequesterRsrc --keepParent "$app" "$base.zip"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "$app_name" -srcfolder "$staging" -fs HFS+ -format UDZO "$base.dmg"
if ((!ad_hoc)); then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$base.dmg"
fi
if ((notarize)); then
  xcrun notarytool submit "$base.dmg" "${notary[@]}" --wait
  xcrun stapler staple "$base.dmg"
fi

echo "==> Writing $(basename "$metadata")"
plutil -create xml1 "$metadata"
plutil -insert version -string "$version" "$metadata"
plutil -insert build -string "$build" "$metadata"
plutil -insert minimumSystemVersion -string "$minimum_system" "$metadata"
notarized=false
if ((notarize)); then
  notarized=true
fi
plutil -insert notarized -bool "$notarized" "$metadata"
plutil -insert zip -string "$(basename "$base.zip")" "$metadata"
plutil -insert dmg -string "$(basename "$base.dmg")" "$metadata"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "==> Signing the update for Sparkle"
  sign_update="$root/.build/artifacts/sparkle/Sparkle/bin/sign_update"
  [[ -x "$sign_update" ]] || fail "Sparkle's sign_update isn't at $sign_update"
  signature="$(printf '%s\n' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --ed-key-file - -p "$base.zip")"
  public_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")"
  swift scripts/check-update-signature.swift "$base.zip" "$signature" "$public_key" \
    || fail "SPARKLE_PRIVATE_KEY doesn't match SPARKLE_PUBLIC_KEY; installed copies would reject this update"
  plutil -insert sparkle -dictionary "$metadata"
  plutil -insert sparkle.edSignature -string "$signature" "$metadata"
  plutil -insert sparkle.length -integer "$(stat -f %z "$base.zip")" "$metadata"
else
  echo "    No SPARKLE_PRIVATE_KEY: this release won't be offered as an update."
fi
plutil -convert json -r "$metadata"

echo
if ((notarize)); then
  echo "Release $version (notarized):"
else
  echo "Release $version (NOT notarized):"
fi
(cd "$out" && shasum -a 256 "$(basename "$base.zip")" "$(basename "$base.dmg")")
