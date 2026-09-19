terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------------
# 1. Automatically Fetch Your Current Public IP (Source: "My IP")
# -------------------------------------------------------------
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# -------------------------------------------------------------
# 2. Automatically Find Official Ubuntu 24.04 LTS HVM SSD AMI
# -------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------------------------------------------
# 3. Generate RSA Key Pair (.pem) & Register with AWS
# -------------------------------------------------------------
resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.rsa_key.public_key_openssh
}

resource "local_file" "pem_file" {
  content         = tls_private_key.rsa_key.private_key_pem
  filename        = pathexpand("~/.ssh/${var.key_pair_name}.pem")
  file_permission = "0400"
}

# -------------------------------------------------------------
# 4. Security Group: ABCD ("This is a test secutity group")
# Rules: SSH (22) & PostgreSQL (5432), Source: My IP
# -------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = var.security_group_name
  description = var.security_group_description

  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  ingress {
    description = "PostgreSQL from My IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name
  }
}

# -------------------------------------------------------------
# 5. EC2 Instance: test-FDE-Database (c7i-flex.large, 20GB SSD)
# -------------------------------------------------------------
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size           = var.disk_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Update system packages
              apt-get update -y
              apt-get install -y curl ca-certificates lsb-release gnupg

              # 2. Add Official PostgreSQL APT Repository
              install -d /usr/share/postgresql-common/pgdg
              curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
              sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

              # 3. Install Target PostgreSQL Version
              apt-get update -y
              apt-get install -y postgresql-${var.pg_version} postgresql-contrib-${var.pg_version}

              # 4. Install pgvector if enabled
              if [ "${var.install_pgvector}" = "true" ]; then
                apt-get install -y postgresql-${var.pg_version}-pgvector || true
              fi

              # 5. Configure Network Access in postgresql.conf & pg_hba.conf
              sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/${var.pg_version}/main/postgresql.conf
              echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/${var.pg_version}/main/pg_hba.conf

              systemctl restart postgresql
              systemctl enable postgresql

              # 6. Initialize Database and Application User (fde_admin)
              sudo -u postgres psql -c "CREATE DATABASE ${var.db_name};"

              sudo -u postgres psql -d ${var.db_name} << 'EOSQL'
              CREATE USER ${var.db_user} WITH PASSWORD '${var.db_password}';
              ALTER ROLE ${var.db_user} SET client_encoding TO 'utf8';
              ALTER ROLE ${var.db_user} SET default_transaction_isolation TO 'read committed';
              ALTER ROLE ${var.db_user} SET timezone TO 'UTC';
              GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO ${var.db_user};
              GRANT ALL ON SCHEMA public TO ${var.db_user};
              ALTER DATABASE ${var.db_name} OWNER TO ${var.db_user};
              EOSQL

              # 7. Enable pgvector extension inside database if enabled
              if [ "${var.install_pgvector}" = "true" ]; then
                sudo -u postgres psql -d ${var.db_name} -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
              fi
              EOF

  tags = {
    Name = var.instance_name
  }
}

# -------------------------------------------------------------
# 6. Static Elastic IP in ap-south-1
# -------------------------------------------------------------
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.instance_name}-elastic-ip"
  }
}

# -------------------------------------------------------------
# 7. Automatically Generate .env in Project Root
# -------------------------------------------------------------
resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
# =============================================================
# Database Configuration (Auto-generated by Terraform)
# =============================================================
DB_HOST=${aws_eip.app_eip.public_ip}
DB_PORT=5432
DB_NAME=${var.db_name}
DB_USER=${var.db_user}
DB_PASSWORD=${var.db_password}

DATABASE_URL=postgresql://${var.db_user}:${var.db_password}@${aws_eip.app_eip.public_ip}:5432/${var.db_name}

# =============================================================
# Cloud Metadata
# =============================================================
AWS_REGION=${var.aws_region}
EC2_PUBLIC_IP=${aws_eip.app_eip.public_ip}
EC2_SSH_USER=ubuntu
SSH_KEY_PATH=~/.ssh/${var.key_pair_name}.pem
EOT
}

# -------------------------------------------------------------
# 8. Outputs
# -------------------------------------------------------------
output "elastic_ip" {
  description = "The static Elastic IP of your server"
  value       = aws_eip.app_eip.public_ip
}

output "detected_my_ip" {
  description = "Your detected public IP that was whitelisted in Security Group ABCD"
  value       = local.my_ip_cidr
}

output "ssh_command" {
  description = "Command to SSH into your server using the .pem key"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.app_eip.public_ip}"
}
