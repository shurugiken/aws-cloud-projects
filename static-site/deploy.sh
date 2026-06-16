#!/usr/bin/env bash
# deploy.sh — Deploy the static site CloudFormation stack
#
# Usage:
#   export DOMAIN_NAME="example.com"
#   export HOSTED_ZONE_ID="Z1234567890EXAMPLE"
#   export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/EXAMPLE-ID"
#   bash deploy.sh
#
# All sensitive/account-specific values come from environment variables.
# Never hardcode account IDs, domain names, or ARNs in this script.

set -euo pipefail

# ---- Validate required env vars ----
: "${DOMAIN_NAME:?Set DOMAIN_NAME (e.g. example.com)}"
: "${HOSTED_ZONE_ID:?Set HOSTED_ZONE_ID (Route 53 hosted zone ID)}"
: "${ACM_CERT_ARN:?Set ACM_CERT_ARN (us-east-1 ACM certificate ARN)}"

STACK_NAME="${STACK_NAME:-static-site-stack}"
TEMPLATE_FILE="$(dirname "$0")/cloudformation.yaml"

echo "Deploying stack: $STACK_NAME"
echo "  Domain:  $DOMAIN_NAME"
echo "  Zone ID: $HOSTED_ZONE_ID"
echo "  Cert:    $ACM_CERT_ARN"
echo ""

# CloudFormation deploy — creates or updates the stack
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides \
    DomainName="$DOMAIN_NAME" \
    HostedZoneId="$HOSTED_ZONE_ID" \
    AcmCertificateArn="$ACM_CERT_ARN" \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo ""
echo "Stack deployed. Outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
