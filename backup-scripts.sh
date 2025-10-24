#!/bin/bash

# PostgreSQL Backup and Recovery Scripts
# This script provides comprehensive backup and recovery functionality

set -e

# Configuration
BACKUP_DIR="/opt/patroni/backups"
S3_BUCKET="${S3_BACKUP_BUCKET}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="postgres_backup_${DATE}.sql.gz"
WAL_ARCHIVE_DIR="/opt/patroni/wal_archive"
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Create necessary directories
create_directories() {
    log "Creating backup directories..."
    mkdir -p $BACKUP_DIR
    mkdir -p $WAL_ARCHIVE_DIR
    chown -R postgres:postgres $BACKUP_DIR
    chown -R postgres:postgres $WAL_ARCHIVE_DIR
}

# Full database backup
full_backup() {
    log "Starting full database backup..."
    
    # Check if PostgreSQL is running
    if ! pg_isready -h localhost -p 5432 -U postgres; then
        error "PostgreSQL is not running or not accessible"
        return 1
    fi
    
    # Perform backup
    sudo -u postgres pg_dumpall -h localhost -U postgres | gzip > $BACKUP_DIR/$BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        log "Backup completed successfully: $BACKUP_FILE"
        
        # Upload to S3
        log "Uploading backup to S3..."
        aws s3 cp $BACKUP_DIR/$BACKUP_FILE s3://$S3_BUCKET/backups/
        
        if [ $? -eq 0 ]; then
            log "Backup uploaded to S3 successfully"
        else
            error "Failed to upload backup to S3"
            return 1
        fi
    else
        error "Backup failed"
        return 1
    fi
}

# Clean up old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    
    # Clean local backups older than retention period
    find $BACKUP_DIR -name "postgres_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
    
    # Clean S3 backups older than retention period
    aws s3 ls s3://$S3_BUCKET/backups/ --recursive | while read -r line; do
        createDate=$(echo $line | awk '{print $1" "$2}')
        createDate=$(date -d"$createDate" +%s)
        olderThan=$(date -d"$RETENTION_DAYS days ago" +%s)
        if [[ $createDate -lt $olderThan ]]; then
            fileName=$(echo $line | awk '{print $4}')
            log "Deleting old backup: $fileName"
            aws s3 rm s3://$S3_BUCKET/$fileName
        fi
    done
}

# WAL archiving
wal_archive() {
    log "Setting up WAL archiving..."
    
    # Create WAL archive directory
    mkdir -p $WAL_ARCHIVE_DIR
    
    # Configure PostgreSQL for WAL archiving
    sudo -u postgres psql -c "ALTER SYSTEM SET archive_mode = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET archive_command = 'aws s3 cp %p s3://$S3_BUCKET/wal_archive/%f';"
    sudo -u postgres psql -c "SELECT pg_reload_conf();"
    
    log "WAL archiving configured"
}

# Point-in-time recovery setup
pitr_setup() {
    log "Setting up Point-in-Time Recovery..."
    
    # Create recovery configuration
    cat > /etc/postgresql/15/main/recovery.conf << EOF
restore_command = 'aws s3 cp s3://$S3_BUCKET/wal_archive/%f %p'
recovery_target_timeline = 'latest'
recovery_target_action = 'promote'
EOF
    
    log "PITR configuration created"
}

# Restore from backup
restore_backup() {
    local backup_file=$1
    local target_db=$2
    
    if [ -z "$backup_file" ]; then
        error "Backup file not specified"
        return 1
    fi
    
    if [ -z "$target_db" ]; then
        target_db="postgres"
    fi
    
    log "Restoring from backup: $backup_file to database: $target_db"
    
    # Download backup from S3 if it's an S3 path
    if [[ $backup_file == s3://* ]]; then
        local local_backup="/tmp/$(basename $backup_file)"
        aws s3 cp $backup_file $local_backup
        backup_file=$local_backup
    fi
    
    # Restore database
    if [[ $backup_file == *.gz ]]; then
        gunzip -c $backup_file | sudo -u postgres psql -h localhost -U postgres -d $target_db
    else
        sudo -u postgres psql -h localhost -U postgres -d $target_db < $backup_file
    fi
    
    if [ $? -eq 0 ]; then
        log "Restore completed successfully"
    else
        error "Restore failed"
        return 1
    fi
}

# List available backups
list_backups() {
    log "Available backups:"
    echo "Local backups:"
    ls -la $BACKUP_DIR/postgres_backup_*.sql.gz 2>/dev/null || echo "No local backups found"
    
    echo -e "\nS3 backups:"
    aws s3 ls s3://$S3_BUCKET/backups/ --recursive | awk '{print $1, $2, $4}' | sort -r
}

# Backup verification
verify_backup() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        error "Backup file not specified"
        return 1
    fi
    
    log "Verifying backup: $backup_file"
    
    # Download backup from S3 if it's an S3 path
    if [[ $backup_file == s3://* ]]; then
        local local_backup="/tmp/$(basename $backup_file)"
        aws s3 cp $backup_file $local_backup
        backup_file=$local_backup
    fi
    
    # Verify backup integrity
    if [[ $backup_file == *.gz ]]; then
        if gunzip -t $backup_file; then
            log "Backup file is valid"
        else
            error "Backup file is corrupted"
            return 1
        fi
    else
        log "Backup file verification completed"
    fi
}

# Main function
main() {
    case "$1" in
        "backup")
            create_directories
            full_backup
            cleanup_backups
            ;;
        "restore")
            restore_backup "$2" "$3"
            ;;
        "list")
            list_backups
            ;;
        "verify")
            verify_backup "$2"
            ;;
        "wal-archive")
            wal_archive
            ;;
        "pitr-setup")
            pitr_setup
            ;;
        "cleanup")
            cleanup_backups
            ;;
        *)
            echo "Usage: $0 {backup|restore|list|verify|wal-archive|pitr-setup|cleanup}"
            echo ""
            echo "Commands:"
            echo "  backup                    - Perform full database backup"
            echo "  restore <backup_file> [db] - Restore from backup"
            echo "  list                      - List available backups"
            echo "  verify <backup_file>       - Verify backup integrity"
            echo "  wal-archive               - Setup WAL archiving"
            echo "  pitr-setup               - Setup Point-in-Time Recovery"
            echo "  cleanup                   - Clean up old backups"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
