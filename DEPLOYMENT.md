# Deployment Guide for High-Availability PostgreSQL Cluster

## Prerequisites

Before deploying the cluster, ensure you have:

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **SSH Key Pair** for EC2 access
5. **Datadog Account** with API key
6. **Domain Name** (optional, for SSL certificates)

## Step-by-Step Deployment

### 1. Prepare Environment

```bash
# Clone the repository
git clone <repository-url>
cd postgres-ha-cluster

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# Required variables
aws_region = "us-west-2"
project_name = "my-postgres-cluster"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
datadog_api_key = "your-datadog-api-key"

# Optional customizations
postgres_instance_count = 3
postgres_instance_type = "t3.medium"
postgres_volume_size = 100
backup_retention_days = 30
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

Review the planned changes carefully, especially:
- VPC and subnet configuration
- Security group rules
- Instance types and counts
- S3 bucket for backups

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 6. Verify Deployment

After deployment completes, verify the cluster:

```bash
# Get cluster information
terraform output

# Check load balancer DNS
terraform output load_balancer_dns_name

# Get connection string
terraform output connection_string
```

### 7. Test Connectivity

```bash
# Test PostgreSQL connection
psql "$(terraform output -raw connection_string)"

# Check Patroni status
curl http://$(terraform output -raw postgres_instance_private_ips | jq -r '.[0]'):8008/patroni
```

## Post-Deployment Configuration

### 1. Configure Monitoring

The Datadog agent is automatically installed and configured. Verify monitoring:

```bash
# Check Datadog agent status
sudo systemctl status datadog-agent

# View Datadog logs
sudo journalctl -u datadog-agent -f
```

### 2. Set Up Alerts

Configure alerts in Datadog for:
- High CPU usage (>80%)
- Disk space low (<15% free)
- Replication lag (>1MB)
- Failed backups

### 3. Test Failover

Test automatic failover:

```bash
# Stop primary node
sudo systemctl stop patroni

# Check failover in another node
curl http://node-ip:8008/cluster
```

### 4. Verify Backups

```bash
# Check backup status
sudo -u postgres /opt/patroni/backup.sh list

# Verify S3 backups
aws s3 ls s3://$(terraform output -raw s3_backup_bucket)/backups/
```

## Maintenance Operations

### Scaling the Cluster

To add more nodes:

1. Update `postgres_instance_count` in `terraform.tfvars`
2. Run `terraform apply`

### Updating PostgreSQL Version

1. Update `postgres_version` variable
2. Update user data script
3. Run `terraform apply`

### Backup Management

```bash
# Manual backup
sudo -u postgres /opt/patroni/backup.sh backup

# List backups
sudo -u postgres /opt/patroni/backup.sh list

# Restore from backup
sudo -u postgres /opt/patroni/backup.sh restore s3://bucket/backup.sql.gz
```

## Troubleshooting

### Common Issues

1. **Patroni not starting**:
   ```bash
   sudo systemctl status patroni
   sudo journalctl -u patroni -f
   ```

2. **Replication lag**:
   ```bash
   sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
   ```

3. **Backup failures**:
   ```bash
   aws s3 ls s3://your-backup-bucket/
   ```

### Log Locations

- Patroni logs: `/var/log/patroni/`
- PostgreSQL logs: `/var/log/postgresql/`
- System logs: `journalctl -u patroni`

### Health Checks

```bash
# Check cluster health
curl http://node-ip:8008/cluster

# Check PostgreSQL status
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Check replication status
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

## Security Considerations

### Network Security

- All instances are in private subnets
- Security groups restrict access to necessary ports only
- Load balancer provides SSL termination

### Data Security

- EBS volumes are encrypted at rest
- SSL/TLS for database connections
- Secure password generation and storage

### Access Control

- IAM roles with minimal required permissions
- Security groups with least privilege access
- Regular security updates via system packages

## Performance Optimization

### Database Tuning

The configuration includes optimized settings for:
- Memory allocation
- WAL configuration
- Connection limits
- Query performance

### Monitoring

- CloudWatch metrics for infrastructure
- Datadog metrics for application performance
- Custom dashboards for cluster health

## Disaster Recovery

### Backup Strategy

- Daily full backups to S3
- WAL archiving for point-in-time recovery
- Cross-region backup replication (optional)

### Recovery Procedures

1. **Full Restore**:
   ```bash
   sudo -u postgres /opt/patroni/backup.sh restore backup_file.sql.gz
   ```

2. **Point-in-Time Recovery**:
   ```bash
   # Configure recovery target
   sudo -u postgres psql -c "SELECT pg_wal_replay_pause();"
   # Restore to specific point in time
   ```

## Cost Optimization

### Resource Sizing

- Use appropriate instance types for workload
- Monitor and adjust storage requirements
- Implement auto-scaling for variable workloads

### Backup Management

- Configure appropriate retention policies
- Use S3 lifecycle policies for cost optimization
- Monitor backup storage costs

## Support and Maintenance

### Regular Maintenance

- Monitor cluster health daily
- Review backup logs weekly
- Update security patches monthly
- Review performance metrics quarterly

### Documentation

- Keep deployment documentation updated
- Document any custom configurations
- Maintain runbooks for common operations

## Next Steps

After successful deployment:

1. Configure application connections
2. Set up monitoring dashboards
3. Implement backup verification procedures
4. Plan disaster recovery testing
5. Document operational procedures
