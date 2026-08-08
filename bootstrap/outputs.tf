output "state_bucket_name" {
  description = "Name of the created state bucket, for use as TF_STATE_BUCKET"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the created state bucket"
  value       = aws_s3_bucket.state.arn
}
