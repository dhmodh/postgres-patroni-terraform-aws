#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y postgresql-15 postgresql-client-15 postgresql-contrib-15 \
    python3 python3-pip python3-psycopg2 python3-dev \
    git curl wget unzip htop iotop \
    awscli jq

# Install Patroni
pip3 install patroni[etcd3]==${patroni_version}

# Install Datadog agent
DD_API_KEY=${datadog_api_key} DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Create postgres user and directories
useradd -m -s /bin/bash postgres
mkdir -p /var/lib/postgresql/data
mkdir -p /var/log/postgresql
mkdir -p /etc/patroni
mkdir -p /opt/patroni

# Set ownership
chown -R postgres:postgres /var/lib/postgresql
chown -R postgres:postgres /var/log/postgresql
chown -R postgres:postgres /etc/patroni
chown -R postgres:postgres /opt/patroni

# Create Patroni configuration
cat > /etc/patroni/patroni.yml << EOF
scope: ${cluster_name}
namespace: /patroni/
name: ${node_name}

restapi:
  listen: 0.0.0.0:8008
  connect_address: \${PATRONI_RESTAPI_CONNECT_ADDRESS}

etcd3:
  hosts: localhost:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 30
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_segments: 8
        max_wal_senders: 3
        max_replication_slots: 3
        wal_log_hints: "on"
        archive_mode: "on"
        archive_command: "aws s3 cp %p s3://${s3_backup_bucket}/wal_archive/%f"
        archive_timeout: 300
        checkpoint_completion_target: 0.9
        wal_buffers: 16MB
        shared_buffers: 256MB
        effective_cache_size: 1GB
        maintenance_work_mem: 64MB
        checkpoint_segments: 32
        wal_keep_segments: 32
        max_connections: 100
        shared_preload_libraries: 'pg_stat_statements'

postgresql:
  listen: 0.0.0.0:5432
  connect_address: \${PATRONI_POSTGRESQL_CONNECT_ADDRESS}
  data_dir: /var/lib/postgresql/data
  bin_dir: /usr/lib/postgresql/15/bin
  config_dir: /etc/postgresql/15/main
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: ${postgres_password}
    superuser:
      username: postgres
      password: ${postgres_password}
  parameters:
    unix_socket_directories: '/var/run/postgresql'
    logging_collector: 'on'
    log_directory: '/var/log/postgresql'
    log_filename: 'postgresql-%Y-%m-%d_%H%M%S.log'
    log_rotation_age: '1d'
    log_rotation_size: '100MB'
    log_min_duration_statement: 1000
    log_line_prefix: '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
    log_checkpoints: 'on'
    log_connections: 'on'
    log_disconnections: 'on'
    log_lock_waits: 'on'
    log_temp_files: 0
    log_autovacuum_min_duration: 0
    log_error_verbosity: default
    log_statement: 'ddl'
    log_replication_commands: 'on'

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF

# Create PostgreSQL configuration
cat > /etc/postgresql/15/main/postgresql.conf << EOF
# PostgreSQL configuration for Patroni cluster
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_error_verbosity = default
log_statement = 'ddl'
log_replication_commands = on

# Replication
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
hot_standby = on
wal_keep_segments = 32
wal_sender_timeout = 60s
wal_receiver_timeout = 60s

# Archive
archive_mode = on
archive_command = 'aws s3 cp %p s3://${s3_backup_bucket}/wal_archive/%f'
archive_timeout = 300

# Performance
shared_preload_libraries = 'pg_stat_statements'
track_activity_query_size = 2048
pg_stat_statements.track = all
pg_stat_statements.max = 10000
pg_stat_statements.track_utility = on
EOF

# Create pg_hba.conf
cat > /etc/postgresql/15/main/pg_hba.conf << EOF
# PostgreSQL Client Authentication Configuration File
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all             all             10.0.0.0/8              md5
host    replication     replicator      10.0.0.0/8              md5
EOF

# Create Patroni systemd service
cat > /etc/systemd/system/patroni.service << EOF
[Unit]
Description=Runners to orchestrate a high-availability PostgreSQL
After=network.target

[Service]
Type=notify
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# Create backup script
cat > /opt/patroni/backup.sh << 'EOF'
#!/bin/bash
# PostgreSQL backup script

BACKUP_DIR="/opt/patroni/backups"
S3_BUCKET="${s3_backup_bucket}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="postgres_backup_${DATE}.sql.gz"

# Create backup directory
mkdir -p $BACKUP_DIR

# Perform backup
pg_dumpall -h localhost -U postgres | gzip > $BACKUP_DIR/$BACKUP_FILE

# Upload to S3
aws s3 cp $BACKUP_DIR/$BACKUP_FILE s3://$S3_BUCKET/backups/

# Clean up old backups (keep last 7 days)
find $BACKUP_DIR -name "postgres_backup_*.sql.gz" -mtime +7 -delete

# Clean up S3 backups older than 30 days
aws s3 ls s3://$S3_BUCKET/backups/ --recursive | while read -r line; do
    createDate=$(echo $line | awk '{print $1" "$2}')
    createDate=$(date -d"$createDate" +%s)
    olderThan=$(date -d"30 days ago" +%s)
    if [[ $createDate -lt $olderThan ]]; then
        fileName=$(echo $line | awk '{print $4}')
        aws s3 rm s3://$S3_BUCKET/$fileName
    fi
done
EOF

chmod +x /opt/patroni/backup.sh

# Create cron job for backups
echo "0 2 * * * /opt/patroni/backup.sh" | crontab -u postgres -

# Configure Datadog
cat > /etc/datadog-agent/conf.d/postgres.d/conf.yaml << EOF
init_config:

instances:
  - host: localhost
    port: 5432
    username: datadog
    password: ${postgres_password}
    dbname: postgres
    ssl: False
    tags:
      - env:production
      - service:postgresql
      - cluster:${cluster_name}
EOF

# Create Datadog user in PostgreSQL
sudo -u postgres psql -c "CREATE USER datadog WITH PASSWORD '${postgres_password}';"
sudo -u postgres psql -c "GRANT SELECT ON pg_stat_database TO datadog;"

# Start services
systemctl enable patroni
systemctl start patroni

# Enable CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Log completion
echo "PostgreSQL Patroni cluster setup completed at $(date)" >> /var/log/patroni-setup.log
