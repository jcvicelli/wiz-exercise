data "aws_ami" "amazon_linux_2023" {
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

  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"
  #key_name                    = "wiz-exercise-key"
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mongodb_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.mongodb_profile.name
  user_data_replace_on_change = false

  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 50
      encrypted   = true
    }
  ]

  # Enforce IMDSv2
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
            #!/bin/bash
            set -e

            # Update system
            dnf update -y

            # Install required packages
            dnf install -y jq

            # Istall ssm agent
            sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
            sudo systemctl enable amazon-ssm-agent
            sudo systemctl start amazon-ssm-agent

            # Add MongoDB repository
            cat <<REPO | sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo
            [mongodb-org-7.0]
            name=MongoDB Repository
            baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
            gpgcheck=1
            enabled=1
            gpgkey=https://pgp.mongodb.com/server-7.0.asc
            REPO

            # Install MongoDB
            sudo dnf install -y mongodb-org

            # Configure MongoDB to listen on all interfaces
            sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

            # Start MongoDB
            systemctl start mongod
            systemctl enable mongod

            # Wait for MongoDB to be ready
            sleep 10

            # Fetch credentials from Secrets Manager
            SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mongodb_auth.name} --region eu-central-1 --query SecretString --output text)
            ADMIN_PWD=$(echo $SECRET_JSON | jq -r .admin_password)
            APP_PWD=$(echo $SECRET_JSON | jq -r .password)
            APP_USER=$(echo $SECRET_JSON | jq -r .username)

            # Create admin user
            mongosh admin --eval "db.createUser({user: 'admin', pwd: '$ADMIN_PWD', roles: [{role: 'userAdminAnyDatabase', db: 'admin'}, 'readWriteAnyDatabase']})"

            # Create application user
            mongosh tododb --eval "db.createUser({user: '$APP_USER', pwd: '$APP_PWD', roles: [{role: 'readWrite', db: 'tododb'}]})"

            # Enable authentication
            echo "security:" >> /etc/mongod.conf
            echo "  authorization: enabled" >> /etc/mongod.conf

            # Restart MongoDB with authentication
            systemctl restart mongod
          EOF

  tags = {
    Terraform           = "true"
    Environment         = "dev"
    IntentionalWeakness = "OutdatedSoftware"
  }
}

# Generate a key pair for the instance
# resource "tls_private_key" "pk" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "aws_key_pair" "kp" {
#   key_name   = "wiz-exercise-key"
#   public_key = tls_private_key.pk.public_key_openssh
# }

# resource "local_file" "ssh_key" {
#   content         = tls_private_key.pk.private_key_pem
#   filename        = "${path.module}/wiz-exercise-key.pem"
#   file_permission = "0400"
# }

output "mongodb_public_ip" {
  value = module.ec2_mongodb.public_ip
}

output "mongodb_private_ip" {
  value = module.ec2_mongodb.private_ip
}
