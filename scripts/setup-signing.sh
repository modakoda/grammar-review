#!/usr/bin/env bash
set -euo pipefail

name="Grammar Review Local Signing"
keychain="$HOME/Library/Keychains/login.keychain-db"
if [[ "${1:-}" == "--keychain" ]]; then
  keychain="${2:?--keychain needs a path}"
fi

if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
  echo "\"$name\" already exists in $keychain; nothing to do."
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$work/cert.conf" \
  -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
pass="$(/usr/bin/openssl rand -hex 16)"
/usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" -name "$name" \
  -out "$work/identity.p12" -passout "pass:$pass"
security import "$work/identity.p12" -k "$keychain" -P "$pass" -T /usr/bin/codesign >/dev/null

echo "Created \"$name\" in $keychain."
echo "scripts/build-app.sh will now sign with it. Grant Accessibility once more after the next build;"
echo "later rebuilds keep the permission."
