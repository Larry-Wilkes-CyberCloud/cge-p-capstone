# Security Hub is blocked account-wide in this sandbox account:
#   SubscriptionRequiredException: The AWS Access Key Id needs a subscription
#   for the service
# Confirmed via both `terraform apply` and a direct
# `aws securityhub enable-security-hub` call — this is not an IAM permissions
# gap, it's an account-level restriction (common on training/sandbox-
# provisioned AWS accounts without a full support/billing relationship).
# Left commented out, same treatment the lab doc gives to a potentially
# SCP-blocked AWS Config. The restriction itself, and the fact that it was
# independently confirmed rather than assumed, is the evidence.

# resource "aws_securityhub_account" "this" {}
#
# resource "aws_securityhub_standards_subscription" "nist_800_53" {
#   standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/nist-800-53/v/5.0.0"
#   depends_on    = [aws_securityhub_account.this]
# }
#
# resource "aws_securityhub_standards_subscription" "fsbp" {
#   standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
#   depends_on    = [aws_securityhub_account.this]
# }
