resource "aws_iam_role" "k8s_node_role" {
  name = "k8s_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.k8s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "s3_read_write" {
  role       = aws_iam_role.k8s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Giữ nguyên hoặc hạ xuống ReadWrite nếu muốn
}

resource "aws_iam_instance_profile" "k8s_instance_profile" {
  name = "k8s_instance_profile"
  role = aws_iam_role.k8s_node_role.name
}