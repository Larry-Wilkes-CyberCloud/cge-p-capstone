#!/usr/bin/env bash
# scripts/bundle-sign-upload.sh
# Env vars expected: VAULT, RUN_ID, SHA
set -euo pipefail

BUNDLE="evidence-${RUN_ID}-${SHA}.tar.gz"
( cd evidence && tar czf "../${BUNDLE}" . )
sha256sum "${BUNDLE}" | awk '{print $1}' > "${BUNDLE}.sha256"

cosign sign-blob --yes --bundle "${BUNDLE}.sig.bundle" "${BUNDLE}"

KEY_PREFIX="runs/${RUN_ID}"
aws s3 cp "${BUNDLE}"            "s3://${VAULT}/${KEY_PREFIX}/${BUNDLE}"
aws s3 cp "${BUNDLE}.sha256"     "s3://${VAULT}/${KEY_PREFIX}/${BUNDLE}.sha256"
aws s3 cp "${BUNDLE}.sig.bundle" "s3://${VAULT}/${KEY_PREFIX}/${BUNDLE}.sig.bundle"

VERSION_ID=$(aws s3api head-object --bucket "${VAULT}" --key "${KEY_PREFIX}/${BUNDLE}" --query VersionId --output text)

python3 scripts/make_receipt.py "$RUN_ID" "$VAULT" "$KEY_PREFIX/$BUNDLE" "$VERSION_ID" "$(cat ${BUNDLE}.sha256)" "$SHA" > receipt.json

aws s3 cp receipt.json "s3://${VAULT}/${KEY_PREFIX}/receipt.json"
