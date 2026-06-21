# Project 2: IAM Least-Privilege + CloudWatch Monitoring

## Overview

This lab demonstrates the **principle of least privilege** in AWS IAM and pairs it with CloudWatch alerting so you know immediately if something goes wrong. These two practices — tight access control and operational visibility — are the foundation of secure cloud operations.

## The Problem Least Privilege Solves

A common mistake is attaching `AmazonS3FullAccess` (or worse, `AdministratorAccess`) to a role because it "just works." The problem: if that role is ever compromised or misused, the blast radius is massive. Least privilege means granting **only what is needed, to the specific resource it's needed on, and nothing else**.

## Files

| File | Purpose |
|---|---|
| `example-policy.json` | Least-privilege IAM policy: read-only access to one specific S3 bucket |
| `cloudwatch-alarm.json` | CloudWatch alarm definition: fires on elevated S3 4xx error rate |
| `attach-policy.sh` | Script to create the policy and attach it to a role via AWS CLI |

## IAM Policy Design

The policy in `example-policy.json` grants:

- `s3:GetObject` — read individual objects (scoped to the target bucket's objects)
- `s3:ListBucket` — list objects in the bucket (scoped to the bucket itself)
- Explicit `Deny` on `s3:DeleteObject` — defense-in-depth; overrides any Allow from other policies

**What it does NOT grant:**
- No `s3:PutObject` (no writes)
- No `s3:DeleteBucket` (no bucket deletion)
- No access to any other bucket
- No IAM, EC2, or other service access

### Why Explicit Deny?

In AWS IAM, an explicit `Deny` always overrides an `Allow`. If this role is ever attached to an additional broader policy by mistake, the `Deny` on `DeleteObject` still holds. Belt and suspenders.

## CloudWatch Alarm Design

The alarm in `cloudwatch-alarm.json` monitors `4XXError` metrics on the target S3 bucket and triggers when the error rate exceeds threshold. This catches:

- Access denied errors (misconfigured policy)
- Not found errors (broken links or missing assets)
- Permission issues from other services trying to reach the bucket

The alarm publishes to an SNS topic, which sends email notifications.

## How to Deploy

```bash
# Set your values via environment variables
export AWS_ACCOUNT_ID="123456789012"
export TARGET_BUCKET_NAME="my-app-assets-bucket"
export ROLE_NAME="app-readonly-role"
export SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:ops-alerts"

# Create and attach the policy
bash attach-policy.sh

# Create the CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --cli-input-json file://cloudwatch-alarm.json
```

## What It Taught

| Concept | Why It Matters |
|---|---|
| Resource ARN scoping | `arn:aws:s3:::bucket-name/*` vs `arn:aws:s3:::*` — one typo is the difference between read-one-bucket and read-everything |
| Explicit Deny | Defense-in-depth against policy accumulation errors |
| Conditions in IAM | You can restrict by IP (`aws:SourceIp`), require MFA (`aws:MultiFactorAuthPresent`), or limit to specific request times |
| CloudWatch metric alarms | Turns raw API metrics into proactive notifications without a SIEM |
| SNS for alerting | Simple, durable, multi-protocol — email, SMS, Lambda, SQS — one alarm can fan out to all |

## Security Best Practices Applied

- No inline policies — managed policies are reusable and auditable
- No wildcards on resource ARNs in Allow statements
- Explicit Deny as a safety net
- Monitoring tied directly to the resource being protected
- All sensitive values (account IDs, ARNs) passed via environment variables
