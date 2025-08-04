#!/bin/bash

# BookingBridge Disaster Recovery Script
# Comprehensive disaster recovery procedures for production database

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../backup/backup.conf"
LOG_FILE="${LOG_DIR:-/var/log}/bookingbridge-recovery.log"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Default configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bookingbridge}"
DB_USER="${DB_USER:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/opt/bookingbridge/backups}"
S3_BUCKET="${S3_BUCKET:-}"

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

# Send notifications
send_notification() {
    local status="$1"
    local message="$2"
    
    if [ -n "$NOTIFICATION_WEBHOOK" ]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"service\": \"bookingbridge-recovery\"}" \
            2>/dev/null || log_warning "Failed to send notification"
    fi
}

# Disaster assessment
assess_disaster() {
    log_info "Assessing disaster situation..."
    
    local issues=()
    
    # Check database connectivity
    if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -q; then
        issues+=("Database server unreachable")
    fi
    
    # Check database integrity
    export PGPASSWORD="${DB_PASSWORD:-}"
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" &>/dev/null; then
        # Server is reachable, check specific database
        if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
            issues+=("Database '$DB_NAME' is corrupted or missing")
        else
            # Check table integrity
            local table_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
            if [ "$table_count" -lt 5 ]; then
                issues+=("Database appears to have missing tables (only $table_count found)")
            fi
        fi
    fi
    
    # Check disk space
    local available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [ "$available_space" -lt 10 ]; then
        issues+=("Low disk space for recovery operations: ${available_space}GB available")
    fi
    
    # Check backup availability
    local backup_count=$(find "$BACKUP_DIR" -name "bookingbridge_*.sql*" -type f 2>/dev/null | wc -l)
    if [ "$backup_count" -eq 0 ]; then
        issues+=("No local backups found")
    fi
    
    unset PGPASSWORD
    
    if [ ${#issues[@]} -eq 0 ]; then
        log_success "No critical issues detected"
        return 0
    else
        log_error "Disaster assessment found the following issues:"
        for issue in "${issues[@]}"; do
            log_error "  - $issue"
        done
        return 1
    fi
}

# Find latest backup
find_latest_backup() {
    local source="${1:-local}"  # local or s3
    
    case "$source" in
        local)
            local latest_backup=$(find "$BACKUP_DIR" -name "bookingbridge_*.sql*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
            if [ -n "$latest_backup" ]; then
                echo "$latest_backup"
                return 0
            else
                return 1
            fi
            ;;
        s3)
            if [ -z "$S3_BUCKET" ] || ! command -v aws &> /dev/null; then
                return 1
            fi
            
            local latest_s3_backup=$(aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "bookingbridge/" --query 'Contents | sort_by(@, &LastModified) | [-1].Key' --output text)
            if [ "$latest_s3_backup" != "None" ] && [ -n "$latest_s3_backup" ]; then
                echo "s3://$S3_BUCKET/$latest_s3_backup"
                return 0
            else
                return 1
            fi
            ;;
        *)
            log_error "Invalid backup source: $source"
            return 1
            ;;
    esac
}

# Download backup from S3
download_s3_backup() {
    local s3_path="$1"
    local local_path="$BACKUP_DIR/$(basename "$s3_path")"
    
    log_info "Downloading backup from S3: $s3_path"
    
    if aws s3 cp "$s3_path" "$local_path"; then
        log_success "Backup downloaded: $local_path"
        echo "$local_path"
        return 0
    else
        log_error "Failed to download backup from S3"
        return 1
    fi
}

# Point-in-time recovery
point_in_time_recovery() {
    local target_time="$1"
    local backup_file="$2"
    
    log_info "Performing point-in-time recovery to: $target_time"
    log_info "Base backup: $backup_file"
    
    # This is a simplified example - full PITR requires WAL archives
    log_warning "Point-in-time recovery requires WAL archive configuration"
    log_info "Falling back to latest backup restore"
    
    # In a real implementation, you would:
    # 1. Restore base backup
    # 2. Apply WAL files up to target time
    # 3. Set recovery target time
    
    restore_from_backup "$backup_file"
}

# Restore from backup
restore_from_backup() {
    local backup_file="$1"
    local target_db="${2:-$DB_NAME}"
    local restore_mode="${3:-replace}"  # replace, parallel, or test
    
    log_info "Starting database restore..."
    log_info "Backup file: $backup_file"
    log_info "Target database: $target_db"
    log_info "Restore mode: $restore_mode"
    
    # Verify backup integrity first
    if ! "${SCRIPT_DIR}/../backup/backup-database.sh" --verify "$backup_file"; then
        log_error "Backup verification failed"
        return 1
    fi
    
    export PGPASSWORD="${DB_PASSWORD:-}"
    
    # Handle different restore modes
    case "$restore_mode" in
        replace)
            # Stop application services first
            log_warning "This will replace the existing database!"
            read -p "Are you sure you want to continue? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                log_info "Restore cancelled by user"
                return 1
            fi
            
            # Terminate existing connections
            log_info "Terminating existing database connections..."
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "
                SELECT pg_terminate_backend(pid) 
                FROM pg_stat_activity 
                WHERE datname = '$target_db' AND pid <> pg_backend_pid();
            " 2>/dev/null || true
            
            # Drop and recreate database
            log_info "Dropping existing database..."
            dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db" 2>/dev/null || true
            
            log_info "Creating new database..."
            createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db"
            ;;
            
        parallel)
            # Create parallel database for testing
            target_db="${target_db}_recovery_$(date +%s)"
            log_info "Creating parallel database: $target_db"
            createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db"
            ;;
            
        test)
            # Create test database
            target_db="${target_db}_test_$(date +%s)"
            log_info "Creating test database: $target_db"
            createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db"
            ;;
    esac
    
    # Prepare backup file for restore
    local restore_file="$backup_file"
    local cleanup_files=()
    
    # Handle encrypted backups
    if [[ "$backup_file" == *.enc ]]; then
        if [ -z "$ENCRYPTION_KEY_FILE" ] || [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
            log_error "Encryption key file required for encrypted backup"
            return 1
        fi
        
        local decrypted_file="/tmp/$(basename "$backup_file" .enc)_$(date +%s)"
        log_info "Decrypting backup..."
        openssl enc -aes-256-cbc -d -in "$backup_file" -out "$decrypted_file" -pass file:"$ENCRYPTION_KEY_FILE"
        restore_file="$decrypted_file"
        cleanup_files+=("$decrypted_file")
    fi
    
    # Handle compressed backups
    if [[ "$restore_file" == *.gz ]]; then
        local uncompressed_file="/tmp/$(basename "$restore_file" .gz)_$(date +%s)"
        log_info "Decompressing backup..."
        gunzip -c "$restore_file" > "$uncompressed_file"
        if [[ " ${cleanup_files[*]} " == *" $restore_file "* ]]; then
            rm "$restore_file"  # Remove decrypted file
        fi
        restore_file="$uncompressed_file"
        cleanup_files+=("$uncompressed_file")
    fi
    
    # Perform the restore
    log_info "Restoring database from: $restore_file"
    local start_time=$(date +%s)
    
    if pg_restore \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$target_db" \
        --verbose \
        --no-password \
        --single-transaction \
        --jobs=4 \
        "$restore_file" \
        2>&1 | tee -a "$LOG_FILE"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Database restore completed successfully in ${duration} seconds"
        
        # Verify restore
        verify_restore "$target_db"
        
        if [ "$restore_mode" = "replace" ]; then
            # Update database statistics
            log_info "Updating database statistics..."
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$target_db" -c "ANALYZE;" 2>/dev/null || true
            
            send_notification "success" "Database restore completed: $target_db"
        fi
        
    else
        log_error "Database restore failed"
        send_notification "error" "Database restore failed"
        
        # Clean up failed database if not replacing
        if [ "$restore_mode" != "replace" ]; then
            dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$target_db" 2>/dev/null || true
        fi
        
        return 1
    fi
    
    # Clean up temporary files
    for file in "${cleanup_files[@]}"; do
        rm -f "$file"
    done
    
    unset PGPASSWORD
    
    log_info "Restored database: $target_db"
    return 0
}

# Verify restore integrity
verify_restore() {
    local db_name="$1"
    
    log_info "Verifying database restore integrity..."
    
    export PGPASSWORD="${DB_PASSWORD:-}"
    
    # Check table count
    local table_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -tAc "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
    ")
    
    # Check for essential tables (adjust based on your schema)
    local essential_tables=("users" "businesses" "attribution_events" "campaigns")
    local missing_tables=()
    
    for table in "${essential_tables[@]}"; do
        local exists=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -tAc "
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_name = '$table'
            );
        ")
        
        if [ "$exists" = "f" ]; then
            missing_tables+=("$table")
        fi
    done
    
    # Check data integrity
    local total_records=0
    for table in "${essential_tables[@]}"; do
        if [[ ! " ${missing_tables[*]} " =~ " ${table} " ]]; then
            local count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$db_name" -tAc "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
            total_records=$((total_records + count))
            log_info "Table $table: $count records"
        fi
    done
    
    unset PGPASSWORD
    
    # Report verification results
    log_info "Verification Results:"
    log_info "  - Total tables: $table_count"
    log_info "  - Total records: $total_records"
    
    if [ ${#missing_tables[@]} -gt 0 ]; then
        log_warning "Missing essential tables: ${missing_tables[*]}"
        return 1
    fi
    
    if [ "$total_records" -eq 0 ]; then
        log_warning "Database appears to be empty"
        return 1
    fi
    
    log_success "Database verification passed"
    return 0
}

# Create recovery report
create_recovery_report() {
    local report_file="$BACKUP_DIR/recovery_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "BookingBridge Disaster Recovery Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo
        echo "Recovery Configuration:"
        echo "- Database: $DB_HOST:$DB_PORT/$DB_NAME"
        echo "- Backup Directory: $BACKUP_DIR"
        echo "- S3 Bucket: ${S3_BUCKET:-Not configured}"
        echo
        echo "Available Backups:"
        echo "Local:"
        ls -lah "$BACKUP_DIR"/bookingbridge_*.sql* 2>/dev/null | tail -5 || echo "  No local backups found"
        echo
        
        if [ -n "$S3_BUCKET" ] && command -v aws &> /dev/null; then
            echo "S3:"
            aws s3 ls "s3://$S3_BUCKET/bookingbridge/" --human-readable | tail -5 || echo "  No S3 backups found"
        fi
        
        echo
        echo "Recovery Procedures Available:"
        echo "1. Full database restore from latest backup"
        echo "2. Point-in-time recovery (requires WAL archives)"
        echo "3. Parallel database creation for testing"
        echo "4. Selective table restore"
        echo
        echo "For emergency recovery, run:"
        echo "$0 --restore-latest"
    } > "$report_file"
    
    log_info "Recovery report generated: $report_file"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Disaster Recovery Options:
    --assess                    Assess current disaster situation
    --restore-latest           Restore from latest available backup
    --restore FILE             Restore from specific backup file
    --restore-s3               Restore from latest S3 backup
    --point-in-time TIME       Point-in-time recovery to specific timestamp
    --parallel-restore FILE    Create parallel database from backup
    --test-restore FILE        Create test database from backup
    --verify-backups           Verify integrity of all available backups
    --report                   Generate disaster recovery report

Recovery Planning:
    --list-backups             List all available backups
    --download-s3 FILE         Download specific backup from S3
    --cleanup-temp             Clean up temporary recovery files

Options:
    -h, --help                 Show this help message
    --config FILE              Use custom configuration file
    --target-db NAME           Target database name for restore
    --no-verify                Skip backup verification before restore

Examples:
    $0 --assess                                    # Assess disaster situation
    $0 --restore-latest                            # Quick recovery from latest backup
    $0 --restore /path/to/backup.sql.gz           # Restore from specific file
    $0 --parallel-restore /path/to/backup.sql.gz  # Create parallel database
    $0 --point-in-time "2024-01-15 14:30:00"      # Point-in-time recovery

Emergency Recovery:
    In case of complete database loss:
    1. $0 --assess
    2. $0 --restore-latest
    3. Verify application functionality
    4. Resume operations

EOF
}

# Main function
main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --assess)
                log_info "Starting disaster assessment..."
                if assess_disaster; then
                    log_success "System appears to be healthy"
                    exit 0
                else
                    log_error "System requires recovery procedures"
                    exit 1
                fi
                ;;
            --restore-latest)
                log_info "Restoring from latest backup..."
                local latest_backup
                if latest_backup=$(find_latest_backup local); then
                    restore_from_backup "$latest_backup"
                elif latest_backup=$(find_latest_backup s3); then
                    local local_backup=$(download_s3_backup "$latest_backup")
                    restore_from_backup "$local_backup"
                else
                    log_error "No backups found for recovery"
                    exit 1
                fi
                exit $?
                ;;
            --restore)
                restore_from_backup "$2"
                exit $?
                ;;
            --restore-s3)
                log_info "Restoring from latest S3 backup..."
                local latest_s3_backup
                if latest_s3_backup=$(find_latest_backup s3); then
                    local local_backup=$(download_s3_backup "$latest_s3_backup")
                    restore_from_backup "$local_backup"
                else
                    log_error "No S3 backups found"
                    exit 1
                fi
                exit $?
                ;;
            --point-in-time)
                point_in_time_recovery "$2" "$(find_latest_backup local)"
                exit $?
                ;;
            --parallel-restore)
                restore_from_backup "$2" "$DB_NAME" "parallel"
                exit $?
                ;;
            --test-restore)
                restore_from_backup "$2" "$DB_NAME" "test"
                exit $?
                ;;
            --report)
                create_recovery_report
                exit 0
                ;;
            --list-backups)
                "${SCRIPT_DIR}/../backup/backup-database.sh" --list
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Default action - show help
    usage
    exit 0
}

# Run main function
main "$@"