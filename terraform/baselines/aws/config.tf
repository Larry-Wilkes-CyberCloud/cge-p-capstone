# AWS Config recorder + delivery channel.
# NOTE: this account's org-level SCP blocks config:* actions for non-management
# accounts. If terraform apply returns:
#   AccessDeniedException: ... explicit deny in a service control policy
# then leave this file's resources commented out. Security Hub's own finding
# "AWS Config should be enabled and use the service-linked role for resource
# recording" becomes the evidence that this gap exists and is a centrally
# managed decision, not an oversight.

# resource "aws_s3_bucket" "config" {
#   bucket        = "cgep-lab-config-${random_id.suffix.hex}"
#   force_destroy = true
# }
#
# resource "aws_s3_bucket_public_access_block" "config" {
#   bucket                  = aws_s3_bucket.config.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }
#
# resource "aws_iam_role" "config" {
#   name = "cgep-lab-config-recorder"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "config.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }
#
# resource "aws_iam_role_policy_attachment" "config" {
#   role       = aws_iam_role.config.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
# }
#
# resource "aws_iam_role_policy" "config_s3" {
#   name = "cgep-lab-config-s3-delivery"
#   role = aws_iam_role.config.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = ["s3:PutObject"]
#       Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
#       Condition = {
#         StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
#       }
#     }]
#   })
# }
#
# resource "aws_config_configuration_recorder" "this" {
#   name     = "cgep-lab-recorder"
#   role_arn = aws_iam_role.config.arn
#
#   recording_group {
#     all_supported = true
#   }
# }
#
# resource "aws_config_delivery_channel" "this" {
#   name           = "cgep-lab-delivery"
#   s3_bucket_name = aws_s3_bucket.config.id
#   depends_on     = [aws_config_configuration_recorder.this]
# }
#
# resource "aws_config_configuration_recorder_status" "this" {
#   name       = aws_config_configuration_recorder.this.name
#   is_enabled = true
#   depends_on = [aws_config_delivery_channel.this]
# }
