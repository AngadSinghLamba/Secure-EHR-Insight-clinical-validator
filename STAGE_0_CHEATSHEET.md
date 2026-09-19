# 🚀 Universal Cloud & Database Infrastructure Cheatsheet (Stage 0)

A modular, production-ready guide to provisioning cloud infrastructure using **Terraform Variables**. 

Instead of hardcoding values, this architecture uses a **3-File Structure** so you can adapt it to any project (Healthcare EHR, FinTech, E-Commerce, AI/RAG) in 30 seconds by simply modifying variables.

---

## 📁 1. The 3-File Architecture

```
terraform/
├── variables.tf         # 📌 Defines what variables exist, their types & default fallbacks
├── terraform.tfvars     # ⚙️ YOUR CONTROL PANEL: Where you plug in values for your specific project
└── main.tf              # 🏗️ The engine that builds the AWS resources & generates ../.env
```

---

## 🎛️ 2. The Customization Matrix: What to Change Project-by-Project

Whenever you start a new project, you only edit **`terraform.tfvars`**. Here is your reference guide for what to change:

### A. Cloud Region Matrix
| Region Code | Location | When to Use |
| :--- | :--- | :--- |
| `ap-south-1` | Mumbai, India | Best latency if you or your users are in India. |
| `us-east-1` | North Virginia, USA | Standard default; cheapest pricing and widest service availability. |
| `eu-central-1` | Frankfurt, Germany | Best for European GDPR compliance requirements. |

---

### B. Machine Size & RAM Matrix (AWS vs GCP vs Azure)
| Desired RAM / CPU | AWS EC2 | GCP Compute Engine | Azure VM | Typical Workload |
| :--- | :--- | :--- | :--- | :--- |
| **1 GB RAM / 1 vCPU** | `t3.micro` *(Free tier)* | `e2-micro` *(Free tier)* | `Standard_B1s` | Simple testing / toy projects |
| **2 GB RAM / 2 vCPU** | `t3.small` | `e2-small` | `Standard_B1ms` | Lightweight APIs |
| **4 GB RAM / 2 vCPU** | **`t3.medium`** *(Current)* | `e2-medium` | `Standard_B2s` | PostgreSQL + Backend API |
| **8 GB RAM / 2 vCPU** | `t3.large` | `e2-standard-2` | `Standard_B2ms` | Heavy analytics, ETL, Airflow |
| **16 GB RAM / 4 vCPU**| `t3.xlarge` | `e2-standard-4` | `Standard_B4ms` | Production databases |

---

### C. Database & AI Stack Matrix
| Requirement | Variable Setting in `terraform.tfvars` | What Terraform Does Automatically |
| :--- | :--- | :--- |
| **PostgreSQL 14 (FDE Standard)** | `pg_version = "14"` | Adds official PGDG repository & installs PG 14. |
| **PostgreSQL 16 (Latest)** | `pg_version = "16"` | Installs PG 16. |
| **AI / Vector Search (RAG)** | `install_pgvector = true` | Installs `pgvector` extension and runs `CREATE EXTENSION vector;`. |
| **Standard Relational Only** | `install_pgvector = false` | Skips vector extension for cleaner installation. |

---

### D. Common Database Port Reference
| Database / Service | Default Port | Security Group Ingress Rule |
| :--- | :--- | :--- |
| **PostgreSQL** | `5432` | `from_port = 5432, to_port = 5432` |
| **MySQL / MariaDB** | `3306` | `from_port = 3306, to_port = 3306` |
| **MongoDB** | `27017` | `from_port = 27017, to_port = 27017` |
| **Redis** | `6379` | `from_port = 6379, to_port = 6379` |
| **FastAPI / Python Web** | `8000` | `from_port = 8000, to_port = 8000` |
| **HTTP / HTTPS Web** | `80` / `443` | `from_port = 80, to_port = 80` / `443` |

---

## ⚙️ 3. File 1: `terraform.tfvars` (Your Control Panel)

Create/edit this file for your specific project:

```hcl
# ==============================================================================
# PROJECT CONFIGURATION (Edit this file for any new project!)
# ==============================================================================

# 1. Cloud Region & Naming
aws_region   = "ap-south-1"  # e.g. ap-south-1 (Mumbai), us-east-1 (N. Virginia)
project_name = "ehr"

# 2. Hardware Specs
instance_type = "t3.medium"  # 4GB RAM, 2 vCPU
disk_size_gb  = 20           # 20 GB gp3 SSD

# 3. SSH Keys
ssh_key_name         = "ehr-ec2-key"
ssh_public_key_path  = "~/.ssh/ehr_ec2_key.pub"
ssh_private_key_path = "~/.ssh/ehr_ec2_key"

# 4. Database & AI Capabilities
pg_version       = "14"                # 14, 15, or 16
install_pgvector = true                # Enable for AI Vector Embeddings / RAG
db_name          = "ehr_db"
db_user          = "fde_admin"
db_password      = "SecureEHR2026!"

# 5. Security (0.0.0.0/0 allows anywhere; in prod replace with your IP/32)
allowed_ssh_cidr = "0.0.0.0/0"
allowed_db_cidr  = "0.0.0.0/0"
```

---

## 📌 4. File 2: `variables.tf` (Variable Definitions)

```hcl
variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ehr"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "disk_size_gb" {
  description = "Root SSD size in GB"
  type        = number
  default     = 20
}

variable "ssh_key_name" {
  type    = string
  default = "ehr-ec2-key"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/ehr_ec2_key.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/ehr_ec2_key"
}

variable "pg_version" {
  type    = string
  default = "14"
}

variable "install_pgvector" {
  type    = bool
  default = true
}

variable "db_name" {
  type    = string
  default = "ehr_db"
}

variable "db_user" {
  type    = string
  default = "fde_admin"
}

variable "db_password" {
  type      = string
  default   = "SecureEHR2026!"
  sensitive = true
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "allowed_db_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
```

---

## 🏗️ 5. File 3: `main.tf` (The Provisioning Engine)

```hcl
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
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Latest Official Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}

# 3. Security Group (Virtual Firewall)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-instance-sg"
  description = "Security Group for ${var.project_name}"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_db_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-security-group"
  }
}

# 4. EC2 Instance with Automated First-Boot Setup
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

              # Update packages
              apt-get update -y
              apt-get install -y curl ca-certificates lsb-release gnupg

              # Official PostgreSQL PGDG Repository
              install -d /usr/share/postgresql-common/pgdg
              curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
              sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

              # Install Target PG Version
              apt-get update -y
              apt-get install -y postgresql-${var.pg_version} postgresql-contrib-${var.pg_version}

              # Install pgvector (AI Embeddings) if enabled
              if [ "${var.install_pgvector}" = "true" ]; then
                apt-get install -y postgresql-${var.pg_version}-pgvector || true
              fi

              # Allow Remote Connections
              sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/${var.pg_version}/main/postgresql.conf
              echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/${var.pg_version}/main/pg_hba.conf

              systemctl restart postgresql
              systemctl enable postgresql

              # Create DB & User with UTC Timezone and Public Schema Access
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

              if [ "${var.install_pgvector}" = "true" ]; then
                sudo -u postgres psql -d ${var.db_name} -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
              fi
              EOF

  tags = {
    Name = "${var.project_name}-backend-server"
  }
}

# 5. Static Elastic IP
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-elastic-ip"
  }
}

# 6. Automatic .env Generator
resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
# Auto-generated by Terraform
DB_HOST=${aws_eip.app_eip.public_ip}
DB_PORT=5432
DB_NAME=${var.db_name}
DB_USER=${var.db_user}
DB_PASSWORD=${var.db_password}

DATABASE_URL=postgresql://${var.db_user}:${var.db_password}@${aws_eip.app_eip.public_ip}:5432/${var.db_name}

AWS_REGION=${var.aws_region}
EC2_PUBLIC_IP=${aws_eip.app_eip.public_ip}
EC2_SSH_USER=ubuntu
SSH_KEY_PATH=${var.ssh_private_key_path}
EOT
}

# 7. Outputs
output "elastic_ip" {
  value = aws_eip.app_eip.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_eip.app_eip.public_ip}"
}
```

---

## ⚡ 6. Execution Commands

From inside your `terraform/` folder:

```bash
# 1. Download plugins (One-time)
terraform init

# 2. Preview what will be built
terraform plan

# 3. Launch it! (Creates EC2, Elastic IP, installs PG14 + pgvector, creates .env)
terraform apply

# 4. Destroy it when done to keep AWS costs at $0!
terraform destroy
```

---

## 🔍 7. Verification Inside EC2 Server

```bash
# Connect using the output command:
ssh -i ~/.ssh/ehr_ec2_key ubuntu@<ELASTIC_IP>

# If Ghostty terminal gives warning:
export TERM=xterm-256color

# Check PG14 status:
sudo systemctl status postgresql

# Check fde_admin & pgvector in ehr_db:
sudo -u postgres psql -d ehr_db -c "\dx"
# (Shows 'vector' extension is loaded!)

sudo -u postgres psql -d ehr_db -c "\du"
# (Shows 'fde_admin' user exists!)

exit
```
