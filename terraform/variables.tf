# ==============================================================================
# Variables Definition
# ==============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "test-FDE-Database"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c7i-flex.large"
}

variable "disk_size_gb" {
  description = "Root EBS SSD size in GB"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "Name of the key pair"
  type        = string
  default     = "test-FDE-Database"
}

variable "security_group_name" {
  description = "Name of the Security Group"
  type        = string
  default     = "ABCD"
}

variable "security_group_description" {
  description = "Description for the Security Group"
  type        = string
  default     = "This is a test secutity group"
}

# ------------------------------------------------------------------------------
# Database & Software Configurations
# ------------------------------------------------------------------------------

variable "pg_version" {
  description = "PostgreSQL version to install"
  type        = string
  default     = "14"
}

variable "install_pgvector" {
  description = "Whether to install the pgvector extension"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "ehr_db"
}

variable "db_user" {
  description = "Database master/application user"
  type        = string
  default     = "fde_admin"
}

variable "db_password" {
  description = "Database user password"
  type        = string
  default     = "SecureEHR2026!"
  sensitive   = true
}
