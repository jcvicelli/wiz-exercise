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
  # make sure ssm is running before
  user_data = <<-EOF
              #!/bin/bash
              # Istall ssm agent
              sudo dnf install -y amazon-ssm-agent
              sudo systemctl enable amazon-ssm-agent
              sudo systemctl start amazon-ssm-agent
              EOF

  tags = {
    Name = "wiz-exercise-bastion"
  }
}
