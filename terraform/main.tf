resource "aws_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Allow K8s traffic"

  ingress {
    description = "Allow all internal traffic within the cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "k8s-deployer-key"
  public_key = file("~/.ssh/id_rsa.pub") 
}

resource "aws_instance" "master" {
  ami           = "ami-0e7ff22101b84bcff"
  instance_type = "t3.small"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_instance_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # Cho phép IMDSv1 để EBS Driver lấy được quyền
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "k8s-master" }
}

resource "aws_instance" "worker" {
  count         = 3
  ami           = "ami-0e7ff22101b84bcff"
  instance_type = "c7i-flex.large"
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_instance_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # Cho phép IMDSv1
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "k8s-worker-${count.index + 1}" }
}

resource "aws_ec2_tag" "worker_hostname" {
  count       = 3
  resource_id = aws_instance.worker[count.index].id
  key         = "hostname"
  value       = "worker-${count.index + 1}"
}