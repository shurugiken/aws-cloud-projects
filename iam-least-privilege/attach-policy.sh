#!/usr/bin/env bash
# attach-policy.sh — Create a least-privilege IAM managed policy and attach it
# to an existing IAM role.
#
# Usage:
#   export AWS_ACCOUNT_ID="123456789012"
#   export TARGET_BUCKET_NAME="my-app-assets-bucket"
#   export ROLE_NAME="app-readonly-role"
#   bash attach-policy.sh
#
# This script does NOT create the IAM role itself — that should be done
# separately (via CloudFormation or the console) with the appropriate
# trust policy for whichever service will assume the role.

set -euo pipefail

# ---- Validate required env vars ----
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID (12-digit AWS account number)}"
: "${TARGET_BUCKET_NAME:?Set TARGET_BUCKET_NAME (S3 bucket name to grant access to)}"
: "${ROLE_NAME:?Set ROLE_NAME (IAM role to attach the policy to)}"

POLICY_NAME="s3-readonly-${TARGET_BUCKET_NAME}"
TEMPLATE_FILE="$(dirname "$0")/example-policy.json"

echo "Creating least-privilege policy: $POLICY_NAME"
echo "  Target bucket: $TARGET_BUCKET_NAME"
echo "  Attaching to role: $ROLE_NAME"
echo ""

# Substitute the placeholder bucket name in the policy template.
# This produces a temporary file — the template itself stays clean.
TMP_POLICY=$(mktemp /tmp/iam-policy-XXXXXX.json)
trap 'rm -f $TMP_POLICY' EXIT

sed "s/REPLACE_WITH_BUCKET_NAME/${TARGET_BUCKET_NAME}/g" "$TEMPLATE_FILE" > "$TMP_POLICY"

# Create the managed policy (idempotent: fails if it already exists,
# so delete and recreate if you're iterating on the policy document)
POLICY_ARN=$(aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://"$TMP_POLICY" \
  --description "Least-privilege read-only access to s3://$TARGET_BUCKET_NAME" \
  --query 'Policy.Arn' \
  --output text)

echo "Created policy: $POLICY_ARN"

# Attach the managed policy to the role
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN"

echo "Attached policy to role: $ROLE_NAME"
echo ""
echo "Done. To verify:"
echo "  aws iam list-attached-role-policies --role-name $ROLE_NAME"
