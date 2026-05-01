output "master_ip" {
  value = aws_instance.master.public_ip
}

output "worker_ips" {
  value = aws_instance.worker[*].public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.product_images.id
}