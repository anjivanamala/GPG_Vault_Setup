
#!/usr/bin/env bash

set -Eeuo pipefail

VAULT_FILE="secrets.env.gpg"
INPUT_FILE="secrets.env"
TEMP_FILE="${VAULT_FILE}.tmp.$$"

cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT

echo "======================================"
echo "        SDET LOCAL VAULT LOCK"
echo "======================================"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: $INPUT_FILE not found."
    echo "Run ./decrypt.sh first."
    exit 1
fi

# Ensure GPG asks for a fresh passphrase
gpgconf --kill gpg-agent 2>/dev/null || true

echo "Enter your vault passphrase to encrypt:"
echo ""

# Encrypt using AES-256
if ! gpg --quiet \
    --symmetric \
    --cipher-algo AES256 \
    --pineentry-mode loopback \
    --output "$TEMP_FILE" \
    "$INPUT_FILE"; then

    echo "ERROR: Encryption failed."
    exit 1
fi

# Verify encrypted file against original plaintext
echo ""
echo "Verifying encrypted vault..."

if ! gpg --quiet --decrypt "$TEMP_FILE" | cmp -s "$INPUT_FILE" -; then
    echo "ERROR: Vault verification failed."
    echo "Original plaintext has been preserved."
    exit 1
fi

# Replace encrypted vault only after successful verification
mv -f "$TEMP_FILE" "$VAULT_FILE"

# Remove plaintext copy
rm -f "$INPUT_FILE"

echo ""
echo "SUCCESS: Vault encrypted and verified."
echo "Plaintext secrets.env removed."
echo "Safe to commit secrets.env.gpg to Git."