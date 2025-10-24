# High-Availability PostgreSQL Cluster with Patroni and Terraform

This project deploys a highly available, auto-healing PostgreSQL cluster on AWS EC2 using Patroni and managed entirely by Terraform, including automated monitoring via Datadog.

## Architecture

- **PostgreSQL Cluster**: 3-node Patroni cluster with automatic failover
- **Load Balancer**: Application Load Balancer for read/write traffic distribution
- **Monitoring**: Datadog integration for comprehensive monitoring
- **Backups**: Automated S3 backups with point-in-time recovery
- **Security**: Encrypted storage, VPC isolation, and secure access controls

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **SSH Key Pair** for EC2 access
4. **Datadog Account** with API key
5. **Domain Name** (optional, for SSL certificates)

## Quick Start

1. **Clone and configure**:
   ```bash
   git clone <repository-url>
   cd postgres-ha-cluster
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars**:
   ```hcl
   aws_region = "us-west-2"
   project_name = "my-postgres-cluster"
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
   datadog_api_key = "your-datadog-api-key"
   ```

3. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access your cluster**:
   ```bash
   # Get connection details
   terraform output connection_string
   terraform output load_balancer_dns_name
   ```

## Configuration

### Variables

Key variables you can customize in `terraform.tfvars`:

- `postgres_instance_count`: Number of PostgreSQL nodes (default: 3)
- `postgres_instance_type`: EC2 instance type (default: t3.medium)
- `postgres_volume_size`: EBS volume size in GB (default: 100)
- `backup_retention_days`: Backup retention period (default: 30)
- `enable_ssl`: Enable SSL connections (default: true)

### Patroni Configuration

Patroni configuration is automatically generated in `/etc/patroni/patroni.yml` on each node with:
- Automatic failover and recovery
- WAL archiving to S3
- Health checks and monitoring
- Replication settings optimized for HA

### Monitoring

Datadog monitoring includes:
- PostgreSQL performance metrics
- Patroni cluster health
- System resource utilization
- Custom dashboards and alerts

## Usage

### Connecting to PostgreSQL

```bash
# Using psql
psql "postgresql://postgres:password@load-balancer-dns:5432/postgres"

# Using connection string from Terraform output
psql "$(terraform output -raw connection_string)"
```

### Checking Cluster Status

```bash
# Check Patroni status
curl http://node-ip:8008/patroni

# Check cluster health
curl http://node-ip:8008/cluster
```

### Backup and Recovery

Backups are automatically performed daily at 2 AM UTC:
- Full database dumps to S3
- WAL archiving for point-in-time recovery
- Automatic cleanup of old backups

Manual backup:
```bash
sudo -u postgres /opt/patroni/backup.sh
```

## Monitoring and Alerting

### CloudWatch Metrics
- CPU utilization
- Memory usage
- Disk space
- Network I/O

### Datadog Dashboards
- PostgreSQL performance
- Patroni cluster health
- Replication lag
- Connection counts

### Alerts
- High CPU usage (>80%)
- Disk space low (<15% free)
- Replication lag (>1MB)
- Failed backups

## Security Features

- **Encryption at Rest**: All EBS volumes encrypted
- **Encryption in Transit**: SSL/TLS for database connections
- **Network Security**: VPC with private subnets
- **Access Control**: Security groups with minimal required access
- **Secrets Management**: Secure password generation and storage

## Troubleshooting

### Common Issues

1. **Patroni not starting**:
   ```bash
   sudo systemctl status patroni
   sudo journalctl -u patroni -f
   ```

2. **Replication lag**:
   ```bash
   # Check replication status
   sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
   ```

3. **Backup failures**:
   ```bash
   # Check S3 permissions
   aws s3 ls s3://your-backup-bucket/
   ```

### Logs

- Patroni logs: `/var/log/patroni/`
- PostgreSQL logs: `/var/log/postgresql/`
- System logs: `journalctl -u patroni`

## Maintenance

### Scaling

To add more nodes:
1. Update `postgres_instance_count` in `terraform.tfvars`
2. Run `terraform apply`

### Updates

To update PostgreSQL version:
1. Update `postgres_version` variable
2. Update user data script
3. Run `terraform apply`

### Backup Verification

```bash
# List backups
aws s3 ls s3://your-backup-bucket/backups/

# Test restore (on separate instance)
pg_restore -h localhost -U postgres -d testdb backup_file.sql
```

## Cost Optimization

- Use appropriate instance types for your workload
- Enable auto-scaling for variable workloads
- Configure backup retention policies
- Monitor and optimize storage usage

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch and Datadog logs
3. Check Patroni documentation
4. Open an issue in the repository

## License

This project is licensed under the MIT License.
