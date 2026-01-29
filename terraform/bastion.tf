data "aws_ami" "amazon_linux_2023_bastion" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for bastion instance"
  vpc_id      = module.vpc.vpc_id

  # No ingress rules - access via SSM only
  ingress = []

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  count = 1

  ami           = data.aws_ami.amazon_linux_2023_bastion.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnets[0]

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              set -ex
              
              # Install kubectl
              curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
              chmod +x ./kubectl
              mv ./kubectl /usr/local/bin/kubectl

              # Install helm
              curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
              chmod 700 get_helm.sh
              ./get_helm.sh
              
              # Install aws-iam-authenticator
              curl -o aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/amd64/aws-iam-authenticator
              chmod +x ./aws-iam-authenticator
              mv ./aws-iam-authenticator /usr/local/bin/aws-iam-authenticator

              # Install git
              dnf install -y git

              # Configure kubectl
              aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-west-2
              EOF

  tags = {
    Name = "wiz-exercise-bastion"
  }
}
