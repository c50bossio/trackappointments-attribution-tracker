#!/bin/bash

# BookingBridge Database Backup Script
# Creates comprehensive backups with rotation and monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/backup.conf"
LOG_FILE="${LOG_DIR:-/var/log}/bookingbridge-backup.log"

# Default configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bookingbridge}"
DB_USER="${DB_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/opt/bookingbridge/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
S3_BUCKET="${S3_BUCKET:-}"
ENCRYPTION_KEY_FILE="${ENCRYPTION_KEY_FILE:-}"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$*"
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "SUCCESS" "$*"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "WARNING" "$*"
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "ERROR" "$*"
    echo -e "${RED}[ERROR]${NC} $*"
}

# Notification function
send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"service\": \"bookingbridge-backup\"}" \
            2>/dev/null || log_warning "Failed to send notification"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if pg_dump is available
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump is not installed or not in PATH"
        exit 1
    fi
    
    # Check if database is reachable
    if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -q; then
        log_error "Database is not reachable: $DB_HOST:$DB_PORT/$DB_NAME"
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Check disk space (require at least 5GB free)
    available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ "$available_space" -lt 5 ]; then
        log_error "Insufficient disk space. Available: ${available_space}GB, Required: 5GB"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create database backup
create_backup() {
    local backup_date=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/bookingbridge_${backup_date}.sql"
    local compressed_file="${backup_file}.gz"
    local encrypted_file="${compressed_file}.enc"
    
    log_info "Starting database backup..."
    log_info "Backup file: $backup_file"
    
    # Set connection parameters
    export PGPASSWORD="${DB_PASSWORD:-}"
    
    # Create the backup with verbose output and custom format for better compression
    if pg_dump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --verbose \
        --no-password \
        --format=custom \
        --compress=9 \
        --lock-wait-timeout=30000 \
        --file="$backup_file" \
        2>&1 | tee -a "$LOG_FILE"; then
        
        log_success "Database backup created successfully"
        
        # Get backup file size
        backup_size=$(du -h "$backup_file" | cut -f1)
        log_info "Backup size: $backup_size"
        
        # Compress the backup
        log_info "Compressing backup..."
        if gzip "$backup_file"; then
            log_success "Backup compressed successfully"
            backup_file="$compressed_file"
        else
            log_warning "Failed to compress backup, using uncompressed file"
        fi
        
        # Encrypt the backup if encryption key is provided
        if [ -n "$ENCRYPTION_KEY_FILE" ] && [ -f "$ENCRYPTION_KEY_FILE" ]; then
            log_info "Encrypting backup..."
            if openssl enc -aes-256-cbc -salt -in "$backup_file" -out "$encrypted_file" -pass file:"$ENCRYPTION_KEY_FILE"; then
                log_success "Backup encrypted successfully"
                rm "$backup_file"  # Remove unencrypted file
                backup_file="$encrypted_file"
            else
                log_warning "Failed to encrypt backup, keeping unencrypted file"
            fi
        fi
        
        # Create checksum
        local checksum_file="${backup_file}.sha256"
        sha256sum "$backup_file" > "$checksum_file"
        log_info "Checksum created: $checksum_file"
        
        # Upload to S3 if configured
        if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
            log_info "Uploading backup to S3..."
            local s3_key="bookingbridge/$(basename "$backup_file")"
            if aws s3 cp "$backup_file" "s3://$S3_BUCKET/$s3_key" --storage-class STANDARD_IA; then
                log_success "Backup uploaded to S3: s3://$S3_BUCKET/$s3_key"
                # Also upload checksum
                aws s3 cp "$checksum_file" "s3://$S3_BUCKET/${s3_key}.sha256" --storage-class STANDARD_IA
            else
                log_error "Failed to upload backup to S3"
            fi
        fi
        
        # Create backup metadata
        create_backup_metadata "$backup_file" "$backup_size"
        
        send_notification "success" "Database backup completed successfully: $(basename "$backup_file")"
        
    else
        log_error "Database backup failed"
        send_notification "error" "Database backup failed"
        exit 1
    fi
    
    # Unset password
    unset PGPASSWORD
}

# Create backup metadata
create_backup_metadata() {
    local backup_file="$1"
    local backup_size="$2"
    local metadata_file="${backup_file}.meta"
    
    cat > "$metadata_file" << EOF
{
    "backup_file": "$(basename "$backup_file")",
    "database": "$DB_NAME",
    "host": "$DB_HOST",
    "port": $DB_PORT,
    "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_size": "$backup_size",
    "compression": "$(if [[ "$backup_file" == *.gz* ]]; then echo "gzip"; else echo "none"; fi)",
    "encryption": "$(if [[ "$backup_file" == *.enc ]]; then echo "aes-256-cbc"; else echo "none"; fi)",
    "checksum_algorithm": "sha256",
    "pg_dump_version": "$(pg_dump --version | head -n1)",
    "backup_type": "full",
    "retention_days": $RETENTION_DAYS
}
EOF
    
    log_info "Backup metadata created: $metadata_file"
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted_count=0
    
    # Find and delete old backup files
    while IFS= read -r -d '' file; do
        log_info "Deleting old backup: $(basename "$file")"
        rm -f "$file" "${file}.sha256" "${file}.meta"
        deleted_count=$((deleted_count + 1))
    done < <(find "$BACKUP_DIR" -name "bookingbridge_*.sql*" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    # Clean up S3 if configured
    if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
        log_info "Cleaning up old S3 backups..."
        local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "bookingbridge/" --query "Contents[?LastModified<=\`$cutoff_date\`].[Key]" --output text | while read -r key; do
            if [ -n "$key" ] && [ "$key" != "None" ]; then
                log_info "Deleting old S3 backup: $key"
                aws s3 rm "s3://$S3_BUCKET/$key"
            fi
        done
    fi
    
    if [ $deleted_count -gt 0 ]; then
        log_success "Deleted $deleted_count old backup(s)"
    else
        log_info "No old backups to delete"
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    log_info "Verifying backup integrity..."
    
    # Check if backup file exists
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Verify checksum if available
    local checksum_file="${backup_file}.sha256"
    if [ -f "$checksum_file" ]; then
        if sha256sum -c "$checksum_file" > /dev/null 2>&1; then
            log_success "Backup checksum verification passed"
        else
            log_error "Backup checksum verification failed"
            return 1
        fi
    fi
    
    # Test backup readability with pg_restore (if it's a custom format backup)
    if [[ "$backup_file" != *.enc ]]; then
        local test_file="/tmp/test_restore_$(date +%s).log"
        if pg_restore --list "$backup_file" > "$test_file" 2>&1; then
            local table_count=$(grep -c "TABLE DATA" "$test_file" || echo "0")
            log_success "Backup is readable (contains $table_count tables)"
            rm -f "$test_file"
        else
            log_error "Backup file appears to be corrupted"
            rm -f "$test_file"
            return 1
        fi
    fi
    
    return 0
}

# Generate backup report
generate_report() {
    local report_file="$BACKUP_DIR/backup_report_$(date +%Y%m%d).txt"
    
    {
        echo "BookingBridge Database Backup Report"
        echo "Generated: $(date)"
        echo "======================================="
        echo
        echo "Backup Configuration:"
        echo "- Database: $DB_HOST:$DB_PORT/$DB_NAME"
        echo "- Backup Directory: $BACKUP_DIR"
        echo "- Retention Days: $RETENTION_DAYS"
        echo "- S3 Bucket: ${S3_BUCKET:-Not configured}"
        echo "- Encryption: $(if [ -n "$ENCRYPTION_KEY_FILE" ]; then echo "Enabled"; else echo "Disabled"; fi)"
        echo
        echo "Recent Backups:"
        ls -lh "$BACKUP_DIR"/bookingbridge_*.sql* 2>/dev/null | tail -10 | while read -r line; do
            echo "  $line"
        done
        echo
        echo "Disk Usage:"
        df -h "$BACKUP_DIR" | tail -1
        echo
        echo "S3 Backups:" 
        if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
            aws s3 ls "s3://$S3_BUCKET/bookingbridge/" --human-readable | tail -10
        else
            echo "  S3 not configured"
        fi
    } > "$report_file"
    
    log_info "Backup report generated: $report_file"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -c, --config FILE       Use custom configuration file
    -d, --dir DIRECTORY     Backup directory (default: $BACKUP_DIR)
    -r, --retention DAYS    Retention days (default: $RETENTION_DAYS)
    --verify FILE           Verify backup file integrity
    --restore FILE          Restore from backup file
    --list                  List available backups
    --report                Generate backup report only

Environment Variables:
    DB_HOST                 Database host
    DB_PORT                 Database port
    DB_NAME                 Database name
    DB_USER                 Database user
    DB_PASSWORD             Database password
    BACKUP_DIR              Backup directory
    RETENTION_DAYS          Days to keep backups
    S3_BUCKET               S3 bucket for remote backups
    ENCRYPTION_KEY_FILE     File containing encryption key

Examples:
    $0                      # Create backup with default settings
    $0 --retention 60       # Create backup with 60 days retention
    $0 --verify /path/to/backup.sql.gz    # Verify backup integrity
    $0 --list               # List available backups

EOF
}

# List backups
list_backups() {
    log_info "Available backups:"
    echo
    
    if [ -d "$BACKUP_DIR" ]; then
        echo "Local backups in $BACKUP_DIR:"
        ls -lah "$BACKUP_DIR"/bookingbridge_*.sql* 2>/dev/null | while read -r line; do
            echo "  $line"
        done
        echo
    fi
    
    if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
        echo "S3 backups in s3://$S3_BUCKET/bookingbridge/:"
        aws s3 ls "s3://$S3_BUCKET/bookingbridge/" --human-readable --summarize
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    local target_db="${2:-${DB_NAME}_restore_$(date +%s)}"
    
    log_info "Restoring from backup: $backup_file"
    log_info "Target database: $target_db"
    
    # Verify backup first
    if ! verify_backup "$backup_file"; then
        log_error "Backup verification failed, aborting restore"
        exit 1
    fi
    
    # Handle encrypted backups
    local restore_file="$backup_file"
    if [[ "$backup_file" == *.enc ]]; then
        if [ -z "$ENCRYPTION_KEY_FILE" ] || [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
            log_error "Encryption key file required for encrypted backup"
            exit 1
        fi
        
        local decrypted_file="/tmp/$(basename "$backup_file" .enc)_$(date +%s)"
        log_info "Decrypting backup..."
        if openssl enc -aes-256-cbc -d -in "$backup_file" -out "$decrypted_file" -pass file:"$ENCRYPTION_KEY_FILE"; then
            restore_file="$decrypted_file"
        else
            log_error "Failed to decrypt backup"
            exit 1
        fi
    fi
    
    # Handle compressed backups
    if [[ "$restore_file" == *.gz ]]; then
        local uncompressed_file="/tmp/$(basename "$restore_file" .gz)_$(date +%s)"
        log_info "Decompressing backup..."
        if gunzip -c "$restore_file" > "$uncompressed_file"; then
            if [[ "$backup_file" == *.enc ]]; then
                rm "$restore_file"  # Clean up decrypted file
            fi
            restore_file="$uncompressed_file"
        else
            log_error "Failed to decompress backup"
            exit 1
        fi
    fi
    
    # Create target database
    export PGPASSWORD="${DB_PASSWORD:-}"
    
    log_info "Creating target database: $target_db"
    if createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Target database created"
    else
        log_error "Failed to create target database"
        exit 1
    fi
    
    # Restore the backup
    log_info "Restoring backup to $target_db..."
    if pg_restore \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$target_db" \
        --verbose \
        --no-password \
        --single-transaction \
        "$restore_file" \
        2>&1 | tee -a "$LOG_FILE"; then
        
        log_success "Backup restored successfully to $target_db"
        send_notification "success" "Database restore completed: $target_db"
    else
        log_error "Backup restore failed"
        send_notification "error" "Database restore failed"
        exit 1
    fi
    
    # Clean up temporary files
    if [[ "$restore_file" == /tmp/* ]]; then
        rm -f "$restore_file"
    fi
    
    unset PGPASSWORD
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --verify)
                verify_backup "$2"
                exit $?
                ;;
            --restore)
                check_prerequisites
                restore_backup "$2" "$3"
                exit $?
                ;;
            --list)
                list_backups
                exit 0
                ;;
            --report)
                generate_report
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_info "Starting BookingBridge database backup"
    log_info "Configuration loaded from: ${CONFIG_FILE:-default}"
    
    # Run backup process
    check_prerequisites
    create_backup
    cleanup_old_backups
    generate_report
    
    log_success "Backup process completed successfully"
}

# Run main function
main "$@"