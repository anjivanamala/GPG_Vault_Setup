
#!/usr/bin/env bash
set -Eeuo pipefail

VAULT="secrets.env.gpg"
TEMP_PLAIN="secrets.env.rotation.tmp"
TEMP_VAULT="secrets.env.gpg.rotation.tmp"

cleanup() {
    rm -f "$TEMP_PLAIN" "$TEMP_VAULT"
}
trap cleanup EXIT

echo "======================================"
echo "       SDET VAULT PASSPHRASE ROTATION"
echo "======================================"

if [[ ! -f "$VAULT" ]]; then
    echo "ERROR: Encrypted vault not found."
    exit 1
fi

if [[ -e "$TEMP_PLAIN" || -e "$TEMP_VAULT" ]]; then
    echo "ERROR: Rotation temporary files already exist."
    echo "Inspect them before proceeding."
    exit 1
fi

read -r -p "Confirm you are authorized to rotate this vault (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Rotation cancelled."
    exit 1
fi

gpgconf --kill gpg-agent 2>/dev/null || true

echo ""
echo "Enter CURRENT vault passphrase:"

if ! gpg --quiet --output "$TEMP_PLAIN" --decrypt "$VAULT"; then
    echo "ERROR: Current passphrase verification failed."
    exit 1
fi

echo ""
echo "Enter NEW vault passphrase:"

gpgconf --kill gpg-agent 2>/dev/null || true

if ! gpg --quiet \
    --symmetric \
    --cipher-algo AES256 \
    --output "$TEMP_VAULT" \
    "$TEMP_PLAIN"; then
    echo "ERROR: New encryption failed."
    exit 1
fi

echo ""
echo "Verifying new encrypted vault..."

gpgconf --kill gpg-agent 2>/dev/null || true

if ! gpg --quiet --decrypt "$TEMP_VAULT" | cmp -s "$TEMP_PLAIN" -; then
    echo "ERROR: New vault verification failed."
    exit 1
fi

# Preserve the previous encrypted vault until verification succeeds.
BACKUP="${VAULT}.backup"

if [[ -e "$BACKUP" ]]; then
    echo "ERROR: Backup already exists: $BACKUP"
    echo "Inspect it before proceeding."
    exit 1
fi

cp -p "$VAULT" "$BACKUP"
mv -f "$TEMP_VAULT" "$VAULT"

echo ""
echo "SUCCESS: Passphrase rotation completed."
echo "Previous encrypted vault: $BACKUP"
echo "New encrypted vault: $VAULT"
echo "Plaintext temporary file will be removed."