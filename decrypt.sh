#!/usr/bin/env bash

set -euo pipefail

VAULT_FILE="secrets.env.gpg"
OUTPUT_FILE="secrets.env"

echo "======================================"
echo "       SDET LOCAL VAULT UNLOCK"
echo "======================================"

if [[ ! -f "$VAULT_FILE" ]]; then
    echo "ERROR: $VAULT_FILE not found."
    exit 1
fi

if [[ -f "$OUTPUT_FILE" ]]; then
    echo "ERROR: $OUTPUT_FILE already exists."
    echo "Remove or back up the existing file first."
    exit 1
fi

echo "Enter your vault passphrase:"

if gpg --quiet --output "$OUTPUT_FILE" --decrypt "$VAULT_FILE"; then
    echo ""
    echo "SUCCESS: Vault decrypted."
    echo "You can now edit your configuration."
    echo "WARNING: Do not commit secrets.env!"
else
    rm -f "$OUTPUT_FILE"
    echo ""
    echo "ERROR: Decryption failed."
    exit 1
fi