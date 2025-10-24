variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "postgres-ha"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "postgres_instance_count" {
  description = "Number of PostgreSQL instances"
  type        = number
  default     = 3
}

variable "postgres_instance_type" {
  description = "EC2 instance type for PostgreSQL"
  type        = string
  default     = "t3.medium"
}

variable "postgres_volume_size" {
  description = "Size of EBS volume for PostgreSQL data (GB)"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "patroni_version" {
  description = "Patroni version"
  type        = string
  default     = "3.0.2"
}

variable "enable_ssl" {
  description = "Enable SSL for PostgreSQL connections"
  type        = bool
  default     = true
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for ALB"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access PostgreSQL"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for EBS volumes"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit for PostgreSQL connections"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "CloudWatch monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for PostgreSQL instances"
  type        = bool
  default     = false
}

variable "min_capacity" {
  description = "Minimum number of instances for auto scaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of instances for auto scaling"
  type        = number
  default     = 5
}

variable "scale_up_threshold" {
  description = "CPU threshold for scaling up"
  type        = number
  default     = 70
}

variable "scale_down_threshold" {
  description = "CPU threshold for scaling down"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
