# Zero-Install Git Vault
## A GPG-Based Secrets Management Strategy for SDET Teams

**Technology:** Windows Git Bash, GnuPG 2.x, Git, GitHub Actions  
**Encryption:** AES-256  
**Vault format:** Symmetric GPG encryption

---

## 1. Overview

This project demonstrates a lightweight secrets management approach using native GPG encryption.

The objective is to maintain application configuration and credentials in an encrypted file inside the Git repository while ensuring decrypted plaintext files are never committed.

### Architecture

- `secrets.env.gpg` – Encrypted configuration committed to Git.
- `secrets.env` – Local decrypted configuration, excluded from Git.
- `decrypt.sh` – Unlocks the encrypted vault.
- `encrypt.sh` – Encrypts configuration and removes the plaintext copy.
- `rotate-passphrase.sh` – Changes the vault passphrase.

### Developer Experience

Only two commands are required for routine operations:

```bash
./decrypt.sh
./encrypt.sh
```

Passphrases are entered interactively through GPG.

---

## 2. Prerequisites

Install or verify the following:

- Windows 10/11
- Git for Windows
- Git Bash
- GnuPG

Verify GPG installation:

```bash
gpg --version
```

Verify executable location:

```bash
which gpg
```

Expected:

```text
gpg (GnuPG) 2.x.x
/usr/bin/gpg
```

Verify AES-256 support:

```bash
gpg --version
```

Check that AES256 appears in the supported cipher algorithms.

---

## 3. Repository Structure

```text
Maven_Practice/
│
├── .git/
│
├── .github/
│   └── CODEOWNERS              (Future GitHub integration)
│
├── README.md
├── .gitignore
│
├── secrets.env.gpg             (Encrypted vault)
│
├── decrypt.sh                  (Decryption script)
├── encrypt.sh                  (Encryption script)
├── rotate-passphrase.sh        (Passphrase rotation)
│
└── secrets.env                 (Local only - never commit)
```

---

## 4. Step 1 – Configure .gitignore

Create or update `.gitignore` in the repository root.

```gitignore
# Local decrypted secrets
secrets.env
runtime.env

# Vault rotation backups and temporary files
*.backup
*.tmp
```

### Verify Git Ignore Rules

```bash
git check-ignore -v secrets.env
git check-ignore -v runtime.env
```

Expected output should identify the corresponding `.gitignore` rules.

Check whether the files are already tracked:

```bash
git ls-files secrets.env runtime.env
```

Expected: No output.

**Important:** `.gitignore` does not remove files that are already tracked or erase previously committed secrets.

---

## 5. Step 2 – Create secrets.env

Create the local configuration file.

Example:

```env
# Application Configuration
APP_ENV=QA
APP_URL=https://qa.example.com

# Salesforce Configuration
SF_USERNAME=sdet_test_user
SF_PASSWORD=dummy_salesforce_password

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=sdet_user
DB_PASSWORD=dummy_database_password

# API Configuration
API_BASE_URL=https://api.example.com
API_CLIENT_ID=dummy_client_id
API_CLIENT_SECRET=dummy_client_secret

# Execution Configuration
BROWSER=chrome
HEADLESS=true
```

Use dummy values for practice. Never use actual production credentials in a practice repository.

---

## 6. Step 3 – Encrypt the Vault

Execute:

```bash
gpg --symmetric --cipher-algo AES256 \
    --output secrets.env.gpg secrets.env
```

GPG prompts for:

1. New passphrase.
2. Passphrase confirmation.

Use a strong, unique practice passphrase.

The resulting encrypted file is:

```text
secrets.env.gpg
```

Verify:

```bash
ls -lh secrets.env*
```

At this stage, both plaintext and encrypted files exist.

---

## 7. Step 4 – Create decrypt.sh

Create `decrypt.sh`:

```bash
#!/usr/bin/env bash

set -e

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

gpgconf --kill gpg-agent 2>/dev/null || true

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
```

Make executable:

```bash
chmod +x decrypt.sh
```

Execute:

```bash
./decrypt.sh
```

GPG prompts for the existing vault passphrase.

The plaintext configuration is recreated locally.

---

## 8. Step 5 – Create encrypt.sh

Create `encrypt.sh`:

```bash
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

gpgconf --kill gpg-agent 2>/dev/null || true

echo "Enter your vault passphrase to encrypt:"

if ! gpg --quiet \
    --symmetric \
    --cipher-algo AES256 \
    --output "$TEMP_FILE" \
    "$INPUT_FILE"; then

    echo "ERROR: Encryption failed."
    exit 1
fi

echo "Verifying encrypted vault..."

if ! gpg --quiet --decrypt "$TEMP_FILE" | cmp -s "$INPUT_FILE" -; then
    echo "ERROR: Vault verification failed."
    echo "Original plaintext has been preserved."
    exit 1
fi

mv -f "$TEMP_FILE" "$VAULT_FILE"

rm -f "$INPUT_FILE"

echo "SUCCESS: Vault encrypted and verified."
echo "Plaintext secrets.env removed."
echo "Safe to commit secrets.env.gpg to Git."
```

Make executable:

```bash
chmod +x encrypt.sh
```

Execute:

```bash
./encrypt.sh
```

The script:

1. Checks whether plaintext configuration exists.
2. Requests the vault passphrase.
3. Encrypts using AES-256.
4. Verifies the encrypted output against the original.
5. Replaces the previous encrypted vault.
6. Deletes the plaintext file after successful verification.

---

## 9. Step 6 – Passphrase Rotation

Passphrase rotation changes the encryption passphrase without changing the configuration values.

Create `rotate-passphrase.sh`.

The script:

1. Requests authorization confirmation.
2. Requests the current passphrase.
3. Decrypts the existing vault into a temporary file.
4. Requests the new passphrase.
5. Encrypts using the new passphrase.
6. Verifies the new encrypted vault.
7. Preserves the previous encrypted vault as a backup.
8. Replaces the existing encrypted vault.
9. Removes temporary plaintext.

Make executable:

```bash
chmod +x rotate-passphrase.sh
```

Execute:

```bash
./rotate-passphrase.sh
```

### Rotation Verification

Clear the GPG agent cache:

```bash
gpgconf --kill gpg-agent
```

Verify the newly encrypted vault:

```bash
gpg --quiet --decrypt secrets.env.gpg > /dev/null
```

Check the exit status:

```bash
echo $?
```

Expected:

```text
0
```

The backup file:

```text
secrets.env.gpg.backup
```

contains the previous encrypted vault and must remain protected.

Delete it only after successfully validating the new vault.

**Important:** The local confirmation prompt is not real role-based authorization. GitHub CODEOWNERS and branch protection will provide governance for future repository-based rotation approvals.

---

## 10. Step 7 – Complete Developer Workflow

### Initial Setup

```bash
git clone <repository-url>
cd Maven_Practice

chmod +x decrypt.sh encrypt.sh rotate-passphrase.sh

./decrypt.sh
```

Enter the authorized vault passphrase.

### Routine Configuration Update

Unlock:

```bash
./decrypt.sh
```

Edit:

```text
secrets.env
```

Lock:

```bash
./encrypt.sh
```

Commit the encrypted configuration:

```bash
git add secrets.env.gpg
git commit -m "Update encrypted SDET configuration"
```

### Important

Never commit:

- `secrets.env`
- `runtime.env`
- Temporary plaintext files
- Unencrypted credentials

---

## 11. Step 8 – Git Verification

Check repository status:

```bash
git status --short --ignored
```

Expected:

```text
?? .gitignore
?? decrypt.sh
?? encrypt.sh
?? rotate-passphrase.sh
?? secrets.env.gpg
!! secrets.env.gpg.backup
```

The encrypted vault should be tracked.

The plaintext configuration and backup must remain ignored.

Check tracked files:

```bash
git ls-files
```

Verify that `secrets.env` is absent.

---

## 12. Step 9 – Initial Git Commit

Stage the implementation:

```bash
git add .gitignore
git add decrypt.sh
git add encrypt.sh
git add rotate-passphrase.sh
git add secrets.env.gpg
```

Commit:

```bash
git commit -m "Add GPG encrypted local secrets vault"
```

Only the encrypted vault and supporting scripts should be committed.

---

## 13. Future Enhancement – GitHub Actions Integration

Once the repository is pushed to GitHub, we will integrate automated decryption into GitHub Actions.

Planned architecture:

1. Store the vault passphrase in GitHub Actions Secrets.
2. Retrieve the encrypted vault during workflow execution.
3. Decrypt it using GPG.
4. Load the required configuration into the test process.
5. Execute automated tests.
6. Clean up decrypted configuration.

Planned GitHub Secret:

```text
ORGANIZATION_VAULT_KEY
```

The GitHub Actions implementation will use non-interactive decryption through the protected GitHub Secret.

The local developer workflow will remain interactive.

### Future CODEOWNERS Configuration

Planned `.github/CODEOWNERS`:

```text
/secrets.env.gpg @github-org/vault-admins
/rotate-passphrase.sh @github-org/vault-admins
/.github/workflows/ @github-org/vault-admins
```

Branch protection will require designated reviews for sensitive changes.

---

## 14. Security Considerations

- Use a strong, unique vault passphrase.
- Never hardcode passphrases in shell scripts.
- Never pass passphrases through command-line arguments.
- Never commit decrypted configuration.
- Protect GPG backups.
- Remember that `.gitignore` does not protect previously committed files.
- Passphrase rotation does not invalidate historical encrypted Git commits.
- Rotate underlying application credentials if they are exposed.
- GPG agent caching may affect how frequently passphrase prompts appear.
- Removing plaintext files does not guarantee forensic erasure.
- Restrict access to GitHub repository history and encrypted vault files.
- This symmetric-encryption approach provides shared-secret access, not individual developer identity or revocation.

---

## 15. Implementation Status

| Component | Status |
|---|---|
| Git Ignore Configuration | Completed |
| GPG Installation | Completed |
| AES-256 Encryption | Completed |
| Local Decryption Script | Implemented |
| Local Encryption Script | Implemented |
| Passphrase Rotation Script | Implemented and tested |
| Git Tracking Verification | Completed |
| Initial Git Commit | Pending |
| Fresh Developer Clone Test | Pending |
| GitHub Actions Integration | Planned |
| CODEOWNERS Governance | Planned |

---

**Project Objective:** Provide SDET developers with a simple, repeatable way to manage encrypted application configuration using native GPG and Git Bash, without introducing additional secrets-management dependencies for local practice.