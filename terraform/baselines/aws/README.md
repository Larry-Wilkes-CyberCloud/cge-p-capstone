# Lab 5.2 — AWS Security Services Baseline

Deploys the AWS-native compliance backbone: CloudTrail for audit logging, with Security Hub and Config scoped out where the account genuinely restricts them. This lab is as much about proving what an account can and can't do as it is about deploying services — every scoping decision below is backed by a real, captured error, not an assumption.

## What's deployed

| Service | Status | Controls | Evidence |
|---|---|---|---|
| CloudTrail (multi-region, log-file validation) | Deployed | AU-2, AU-12, AU-10 | evidence/lab-5-2/cloudtrail-status.json |
| Security Hub (NIST 800-53 + FSBP standards) | Blocked | RA-5, SI-4 | evidence/lab-5-2/security-hub-restriction.txt |
| AWS Config (recorder + delivery channel) | Not deployed | CM-2, CM-6, CM-8 | Terraform present but commented out in config.tf |

## CloudTrail — AU-2, AU-12, AU-10

Multi-region trail (cgep-lab-mgmt) covering all regions and global service events, with enable_log_file_validation = true. That flag makes CloudTrail emit an hourly digest file signed by an AWS-managed key — AU-10 (audit information integrity) without any extra infrastructure.

Verified live:

- aws cloudtrail get-trail-status returned IsLogging: true, with StartLoggingTime and LatestDeliveryTime both populated within minutes of apply.

## Security Hub — genuinely blocked, not skipped

Security Hub is disabled account-wide in this sandbox account. Both terraform apply (via aws_securityhub_account) and a direct aws securityhub enable-security-hub call independently returned the same error:

    SubscriptionRequiredException: The AWS Access Key Id needs a subscription for the service

This is not an IAM permissions gap — the same credentials that deployed CloudTrail, oidc/, and the evidence vault in earlier labs hit this wall specifically on Security Hub. It's consistent with how some training/sandbox-provisioned AWS accounts restrict services that require a full support/billing relationship (Security Hub, GuardDuty, Detective, Inspector are common examples).

Rather than silently omitting Security Hub, the resources are left in security_hub.tf, fully commented out, with the restriction documented inline and the raw CLI error captured as evidence.

## AWS Config — not deployed

Per the lab's own guidance, Config's resources are included in config.tf but fully commented out. Given Security Hub itself is blocked in this account (see above), Config's role of feeding findings into Security Hub is moot here regardless of whether an SCP would also block it — it was not attempted.

## Path

terraform/baselines/aws/ — main.tf, variables.tf, cloudtrail.tf, security_hub.tf (commented), config.tf (commented), outputs.tf

## Evidence

evidence/lab-5-2/cloudtrail-status.json, evidence/lab-5-2/security-hub-restriction.txt
