# RDS PostgreSQL Instance
# This can either create a new instance or restore from a snapshot

resource "aws_db_instance" "conbench" {
  identifier = "${local.cluster_name}-db"

  # Database Configuration
  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class

  # Only set storage config for new instances, not when restoring from snapshot
  allocated_storage     = var.db_snapshot_identifier == "" ? var.db_allocated_storage : null
  storage_type          = var.db_snapshot_identifier == "" ? "gp3" : null
  storage_encrypted     = var.db_snapshot_identifier == "" ? true : null  # Inherited from snapshot
  max_allocated_storage = var.db_max_allocated_storage

  # Restore from snapshot if provided, otherwise create new
  snapshot_identifier = var.db_snapshot_identifier

  # Database Credentials (not used if restoring from snapshot)
  db_name  = var.db_snapshot_identifier == "" ? var.db_name : null
  username = var.db_snapshot_identifier == "" ? var.db_username : null
  password = var.db_snapshot_identifier == "" ? var.db_password : null

  # If restoring from snapshot, password can be reset after creation
  # You may want to set this to manage password rotation
  manage_master_user_password = var.db_snapshot_identifier != "" ? false : false

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.conbench.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  # Backup Configuration
  backup_retention_period   = var.db_backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  delete_automated_backups  = false
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.cluster_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance and Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  # High Availability (optional - set to true for multi-AZ)
  multi_az = var.db_multi_az

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.conbench.name

  # Upgrades
  auto_minor_version_upgrade = true
  apply_immediately         = var.db_apply_immediately

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-db"
    }
  )

  lifecycle {
    ignore_changes = [
      # Ignore password changes (if managed outside Terraform)
      password,
      # Ignore snapshot identifier after initial creation
      snapshot_identifier,
      # Prevent accidental deletion
      final_snapshot_identifier,
      # When restoring from snapshot, storage config is inherited
      allocated_storage,
      storage_type,
      storage_encrypted,
      kms_key_id,
    ]
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "conbench" {
  name   = "${local.cluster_name}-postgres-params"
  family = "postgres${split(".", var.db_engine_version)[0]}"

  # Tuning parameters based on conbench usage
  # Static parameters require pending-reboot apply method
  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_buffers"
    value        = "{DBInstanceClassMemory/4096}" # 25% of available memory
    apply_method = "pending-reboot"
  }

  # Dynamic parameters can be applied immediately
  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory*3/4096}" # 75% of available memory
  }

  parameter {
    name  = "work_mem"
    value = "16384" # 16MB
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "524288" # 512MB
  }

  tags = local.common_tags
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.cluster_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Optional: RDS Read Replica (uncomment if needed)
# resource "aws_db_instance" "conbench_read_replica" {
#   identifier             = "${local.cluster_name}-db-replica"
#   replicate_source_db    = aws_db_instance.conbench.identifier
#   instance_class         = var.db_instance_class
#   publicly_accessible    = false
#   skip_final_snapshot    = true
#   vpc_security_group_ids = [aws_security_group.rds.id]
#
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.cluster_name}-db-replica"
#     }
#   )
# }
