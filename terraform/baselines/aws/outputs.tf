output "cloudtrail_name" {
  value = aws_cloudtrail.mgmt.name
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}
