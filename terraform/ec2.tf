data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "mongodb_sg" {
  name        = "mongodb-sg"
  description = "Security group for MongoDB instance"
  vpc_id      = module.vpc.vpc_id

  # Intentional Weakness: SSH open to world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere (Intentional Weakness)"
  }

  # MongoDB restricted to VPC (Private subnets effectively)
  # Ideally strictly private subnets, but VPC CIDR is acceptable as a baseline restriction
  # relying on architecture to ensure EKS is in private.
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    description = "MongoDB access from Private Subnets"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongodb-sg"
  }
}

module "ec2_mongodb" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6.0"

  name = "wiz-exercise-mongodb"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = "wiz-exercise-key"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Install dependencies
              apt-get update
              apt-get install -y unzip jq
              
              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              ./aws/install

              # Install MongoDB 4.4 (Outdated)
              curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
              echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
              apt-get update
              apt-get install -y mongodb-org=4.4.18 mongodb-org-server=4.4.18 mongodb-org-shell=4.4.18 mongodb-org-mongos=4.4.18 mongodb-org-tools=4.4.18
              
              # Hold package versions
              echo "mongodb-org hold" | sudo dpkg --set-selections
              echo "mongodb-org-server hold" | sudo dpkg --set-selections
              echo "mongodb-org-shell hold" | sudo dpkg --set-selections
              echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
              echo "mongodb-org-tools hold" | sudo dpkg --set-selections

              # Configure MongoDB to listen on all interfaces
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              
              systemctl start mongod
              systemctl enable mongod

              # Wait for startup
              sleep 10

              # Fetch Secrets
              SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_auth.name} --region us-west-2 --query SecretString --output text)
              ADMIN_PWD=$(echo $SECRET_JSON | jq -r .admin_password)
              APP_PWD=$(echo $SECRET_JSON | jq -r .password)
              APP_USER=$(echo $SECRET_JSON | jq -r .username)

              # Create Users
              mongo admin --eval "db.createUser({user: 'admin', pwd: '$ADMIN_PWD', roles: [{role: 'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})"
              mongo tododb --eval "db.createUser({user: '$APP_USER', pwd: '$APP_PWD', roles: [{role: 'readWrite', db: 'tododb'}]})"

              # Enable Auth and restart
              echo "security:
                authorization: enabled" >> /etc/mongod.conf
              
              systemctl restart mongod
              EOF

  tags = {
    Terraform           = "true"
    Environment         = "dev"
    IntentionalWeakness = "OutdatedSoftware"
  }
}

# Generate a key pair for the instance
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "wiz-exercise-key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  content         = tls_private_key.pk.private_key_pem
  filename        = "${path.module}/wiz-exercise-key.pem"
  file_permission = "0400"
}

output "mongodb_public_ip" {
  value = module.ec2_mongodb.public_ip
}

output "mongodb_private_ip" {
  value = module.ec2_mongodb.private_ip
}