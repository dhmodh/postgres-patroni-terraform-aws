output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "postgres_instance_ids" {
  description = "IDs of the PostgreSQL instances"
  value       = aws_instance.postgres[*].id
}

output "postgres_instance_private_ips" {
  description = "Private IP addresses of the PostgreSQL instances"
  value       = aws_instance.postgres[*].private_ip
}

output "postgres_instance_public_ips" {
  description = "Public IP addresses of the PostgreSQL instances"
  value       = aws_instance.postgres[*].public_ip
}

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.postgres.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.postgres.zone_id
}

output "postgres_password" {
  description = "PostgreSQL password"
  value       = random_password.postgres_password.result
  sensitive   = true
}

output "s3_backup_bucket" {
  description = "S3 bucket name for backups"
  value       = aws_s3_bucket.backups.bucket
}

output "s3_backup_bucket_arn" {
  description = "S3 bucket ARN for backups"
  value       = aws_s3_bucket.backups.arn
}

output "security_group_id" {
  description = "ID of the PostgreSQL security group"
  value       = aws_security_group.postgres.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.postgres.name
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://postgres:${random_password.postgres_password.result}@${aws_lb.postgres.dns_name}:5432/postgres"
  sensitive   = true
}

output "patroni_rest_api_urls" {
  description = "Patroni REST API URLs for each instance"
  value = {
    for i, instance in aws_instance.postgres : "postgres-${i + 1}" => "http://${instance.private_ip}:8008"
  }
}

output "ssh_connection_commands" {
  description = "SSH connection commands for each instance"
  value = {
    for i, instance in aws_instance.postgres : "postgres-${i + 1}" => "ssh -i your-key.pem ubuntu@${instance.public_ip}"
  }
}

output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-postgres"
}

output "datadog_dashboard_url" {
  description = "Datadog dashboard URL (configure in Datadog console)"
  value       = "https://app.datadoghq.com/dashboard/lists"
}
