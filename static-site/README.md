# Project 1: Static Website — S3 + CloudFront + Route 53 + ACM

## Overview

This lab provisions a fully HTTPS-enforced static website using AWS managed services. The S3 bucket is **never public** — CloudFront accesses it through Origin Access Control (OAC), which is the modern replacement for the deprecated Origin Access Identity (OAI).

## Prerequisites

- AWS CLI configured (`aws configure`)
- A domain registered in Route 53 (or a hosted zone already created)
- Permissions: S3, CloudFront, Route 53, ACM, CloudFormation

## Files

| File | Purpose |
|---|---|
| `cloudformation.yaml` | Provisions S3 bucket, OAC, CloudFront distribution, ACM cert, Route 53 records |
| `deploy.sh` | Wrapper script to deploy the stack with parameter overrides |

## How to Deploy

```bash
# 1. Clone the repo and enter this directory
cd static-site

# 2. Set your domain in an environment variable (never hardcode)
export DOMAIN_NAME="example.com"
export HOSTED_ZONE_ID="Z1234567890EXAMPLE"
export STACK_NAME="static-site-stack"

# 3. Deploy the CloudFormation stack
bash deploy.sh

# 4. Upload your site content
export BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
  --output text)

aws s3 sync ./site-content/ s3://$BUCKET_NAME/ --delete
```

## Key Design Decisions

### Why OAC instead of making the bucket public?

A public S3 bucket is a data exposure risk — anyone with the S3 URL bypasses CloudFront entirely (no HTTPS enforcement, no WAF, no geo-blocking). OAC restricts access so only your CloudFront distribution can read the bucket, enforced by a signed request at the AWS service layer.

### Why ACM in us-east-1?

CloudFront is a global service that requires its TLS certificates to be in `us-east-1`, regardless of where your users or origin bucket are. ACM certificates in other regions are valid for regional services (like ALB) but not CloudFront.

### Why Route 53 Alias instead of CNAME?

- Alias records are **free** (CNAMEs to AWS resources cost per query)
- Alias records work at the **zone apex** (`example.com`) — CNAMEs cannot
- Alias records automatically follow CloudFront IP changes

## Architecture Diagram

```
[Browser]
    |
    | HTTPS (port 443)
    v
[Route 53]
  Alias A record: example.com → d1234abcd.cloudfront.net
    |
    v
[CloudFront Distribution]
  - ACM TLS cert (us-east-1)
  - Redirect HTTP → HTTPS
  - Compress objects
  - Default TTL: 86400s (1 day)
  - Origin: S3 via OAC
    |
    | Signed S3 request (SigV4)
    v
[S3 Bucket — PRIVATE]
  - Block all public access: ON
  - Versioning: enabled
  - Server-side encryption: AES-256
  - Bucket policy: Allow CloudFront OAC only
```

## Teardown

```bash
# Empty the bucket first (CloudFormation cannot delete a non-empty bucket)
aws s3 rm s3://$BUCKET_NAME --recursive

# Delete the stack
aws cloudformation delete-stack --stack-name $STACK_NAME
```
