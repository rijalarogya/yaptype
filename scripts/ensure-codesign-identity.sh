#!/bin/zsh
set -euo pipefail

# Prints the SHA-1 hash of a valid Yaptype Developer identity.
CERT_NAME="${YAPTYPE_CODESIGN_IDENTITY:-Yaptype Developer}"

identity_hash() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -v name="$CERT_NAME" '
        $0 ~ name {
          print $2
          found=1
          exit
        }
        END { if (!found) exit 1 }
      '
}

if HASH="$(identity_hash)"; then
  printf '%s\n' "$HASH"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
if [[ ! -f "$KEYCHAIN" ]]; then
  KEYCHAIN="${HOME}/Library/Keychains/login.keychain"
fi

cat > "$TMP/codesign.cnf" <<'EOF'
[req]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ext
[req_distinguished_name]
CN = Yaptype Developer
O = Yaptype
OU = Yaptype
[v3_ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" \
  -out "$TMP/cert.pem" \
  -config "$TMP/codesign.cnf"

openssl pkcs12 -export \
  -inkey "$TMP/key.pem" \
  -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" \
  -passout pass:yaptype \
  -name "$CERT_NAME"

security import "$TMP/cert.p12" \
  -k "$KEYCHAIN" \
  -P yaptype \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null || true

security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "" \
  "$KEYCHAIN" >/dev/null 2>&1 || true

if ! HASH="$(identity_hash)"; then
  echo "Failed to create codesigning identity '$CERT_NAME'" >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

printf '%s\n' "$HASH"
