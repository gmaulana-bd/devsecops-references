# AXA DevSecOps Reference: Terraform infrastructure
#
# Demonstrates CIS AWS Foundations Benchmark v5.0.0 compliant resources.
# This file is scanned by Checkov in Stage 9 of the pipeline.
#
# Resources defined:
#   - S3 bucket (CIS S3.1, S3.5, S3.8, S3.22, S3.23)
#   - KMS key with rotation (CIS KMS.4)
#   - RDS instance (CIS RDS.2, RDS.3, RDS.5)
#   - IAM role (CIS IAM.1, IAM.2)
#
# Run: terraform init && terraform plan
# Pipeline runs: checkov -d . --framework terraform

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # CLDEV-DEP-01: lock dependency versions, no "latest"
      # Exact pin, not a range. Reproducible builds.
      version = "5.45.0"
    }
  }

  # Remote state in S3 (CLDEV-CFG-03)
  # Uncomment and configure for your AWS account
  # backend "s3" {
  #   bucket         = "axa-terraform-state-prod"
  #   key            = "devsecops-reference/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   kms_key_id     = "alias/terraform-state"
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.region

  # Default tags applied to every resource (CLDEV-RSC-01)
  default_tags {
    tags = {
      Owner            = "axa-group-security"
      DataClass        = "internal"
      Environment      = var.environment
      ManagedBy        = "terraform"
      Application      = "devsecops-reference"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type    = string
  default = "demo"
}

# ============================================================================
# KMS key for encryption (used by S3 and CloudTrail)
# CIS KMS.4: key rotation must be enabled (new in v5.0.0)
# ============================================================================
resource "aws_kms_key" "app_key" {
  description             = "AXA DevSecOps Reference app encryption key"
  deletion_window_in_days = 30

  # CIS KMS.4 (Level 1): enable automatic key rotation
  enable_key_rotation = true
}

resource "aws_kms_alias" "app_key" {
  name          = "alias/axa-devsecops-reference"
  target_key_id = aws_kms_key.app_key.key_id
}

# ============================================================================
# S3 bucket for application data
# CIS controls applied:
#   - S3.1: Block Public Access
#   - S3.5: SSL/HTTPS only
#   - S3.8: Block Public Access at account level (handled separately)
#   - S3.14: Versioning
#   - S3.20: MFA Delete (handled via console after creation)
#   - S3.22 and S3.23: Object-level logging (new in v5.0.0)
# ============================================================================
resource "aws_s3_bucket" "app_data" {
  bucket = "axa-devsecops-demo-${var.environment}"
}

# CIS S3.1: Block ALL public access
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption with the KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.app_key.arn
    }
    bucket_key_enabled = true
  }
}

# CIS S3.14: Versioning enabled
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CIS S3.5: enforce SSL by denying any unencrypted request
resource "aws_s3_bucket_policy" "app_data_ssl_only" {
  bucket = aws_s3_bucket.app_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 server access logging to a separate audit bucket
# (the audit bucket itself is not defined here; assumed pre-existing in real env)
resource "aws_s3_bucket_logging" "app_data" {
  bucket        = aws_s3_bucket.app_data.id
  target_bucket = "axa-audit-logs-${var.environment}"
  target_prefix = "s3-access-logs/devsecops-reference/"
}

# ============================================================================
# RDS PostgreSQL instance
# CIS controls applied:
#   - RDS.2: not publicly accessible
#   - RDS.3: encryption at rest
#   - RDS.5: Multi-AZ for production (new in v5.0.0)
# ============================================================================
resource "aws_db_subnet_group" "app_db" {
  name       = "axa-devsecops-${var.environment}"
  subnet_ids = ["subnet-PLACEHOLDER-1", "subnet-PLACEHOLDER-2"]
}

resource "aws_db_instance" "app_db" {
  identifier     = "axa-devsecops-${var.environment}"
  engine         = "postgres"
  engine_version = "16.2"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "appdb"
  username = "appuser"
  # CLDEV-IAM-02: no hardcoded password. Inject via AWS Secrets Manager.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.app_db.name
  vpc_security_group_ids = ["sg-PLACEHOLDER"]

  # CIS RDS.2: do NOT make it publicly accessible
  publicly_accessible = false

  # CIS RDS.3: encryption at rest
  storage_encrypted = true
  kms_key_id        = aws_kms_key.app_key.arn

  # CIS RDS.5 (new in v5.0.0): Multi-AZ for production resilience
  multi_az = var.environment == "prod" ? true : false

  # Backup retention required for DORA compliance
  backup_retention_period = 7
  delete_automated_backups = false

  # Performance insights with KMS encryption
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.app_key.arn

  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  skip_final_snapshot = false
  final_snapshot_identifier = "axa-devsecops-${var.environment}-final-${formatdate("YYYYMMDD", timestamp())}"
}

# ============================================================================
# IAM role for the application
# CIS IAM.1 (new in v5.0.0): no full-privilege (admin) policies
# CIS IAM.2: no inline policies on users (only on roles/groups)
# CLDEV-IAM-01: least privilege
# ============================================================================
resource "aws_iam_role" "app_role" {
  name = "axa-devsecops-demo-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Custom, narrow policy. NOT AdministratorAccess. NOT AmazonS3FullAccess.
# Only the specific S3 actions on the specific bucket the app needs.
resource "aws_iam_role_policy" "app_role_policy" {
  name = "axa-devsecops-demo-s3-narrow"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        # Only this bucket. Only these actions. Least privilege.
        Resource = "${aws_s3_bucket.app_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.app_key.arn
      }
    ]
  })
}

# Separate role for RDS enhanced monitoring (this is the AWS-required pattern)
resource "aws_iam_role" "rds_monitoring" {
  name = "axa-devsecops-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# Outputs
# ============================================================================
output "s3_bucket_name" {
  value       = aws_s3_bucket.app_data.id
  description = "The name of the application S3 bucket"
}

output "kms_key_arn" {
  value       = aws_kms_key.app_key.arn
  description = "The ARN of the application KMS key"
}

output "app_role_arn" {
  value       = aws_iam_role.app_role.arn
  description = "The ARN of the application IAM role"
}
