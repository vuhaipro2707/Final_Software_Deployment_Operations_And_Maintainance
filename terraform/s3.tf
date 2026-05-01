# 1. Tạo Bucket S3
resource "aws_s3_bucket" "product_images" {
  bucket = var.s3_bucket_name
  
  tags = {
    Name        = "K8s Project Storage"
    Environment = "Dev"
  }
}

# 2. Tắt các chế độ chặn truy cập công cộng (để khách xem được ảnh)
resource "aws_s3_bucket_public_access_block" "product_images_access" {
  bucket = aws_s3_bucket.product_images.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 3. Cấu hình Policy cho phép mọi người đọc ảnh (Public Read)
resource "aws_s3_bucket_policy" "allow_public_read" {
  depends_on = [aws_s3_bucket_public_access_block.product_images_access]
  bucket = aws_s3_bucket.product_images.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.product_images.arn}/*"
      }
    ]
  })
}