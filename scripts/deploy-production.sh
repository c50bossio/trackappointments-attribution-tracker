#!/bin/bash

# BookingBridge Production Deployment Script
# Enterprise-grade deployment with comprehensive checks and rollback capabilities
#
# Usage: ./deploy-production.sh [options]
# Options:
#   --skip-tests      Skip pre-deployment tests
#   --skip-backup     Skip pre-deployment backup
#   --dry-run         Show what would be deployed without actually deploying
#   --rollback        Rollback to previous deployment
#   --help            Show this help message

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENT_LOG="/tmp/bookingbridge-deployment-$(date +%Y%m%d-%H%M%S).log"
LOCK_FILE="/tmp/bookingbridge-deployment.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
SKIP_TESTS=false
SKIP_BACKUP=false
DRY_RUN=false
ROLLBACK=false
ENVIRONMENT="production"

# Production configuration
PRODUCTION_URL="https://bookingbridge.com"
STAGING_URL="https://staging.bookingbridge.com"
REGISTRY="ghcr.io"
IMAGE_NAME="bookingbridge"
NAMESPACE="bookingbridge"

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$DEPLOYMENT_LOG" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$DEPLOYMENT_LOG" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" | tee -a "$DEPLOYMENT_LOG" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$DEPLOYMENT_LOG" ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
BookingBridge Production Deployment Script

Usage: $0 [options]

Options:
    --skip-tests      Skip pre-deployment tests
    --skip-backup     Skip pre-deployment backup
    --dry-run         Show what would be deployed without actually deploying
    --rollback        Rollback to previous deployment
    --help            Show this help message

Examples:
    $0                      # Full production deployment
    $0 --dry-run           # See what would be deployed
    $0 --skip-tests        # Deploy without running tests
    $0 --rollback          # Rollback to previous version

EOF
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking deployment prerequisites..."
    
    # Check if deployment lock exists
    if [[ -f "$LOCK_FILE" ]]; then
        error_exit "Another deployment is already in progress. Lock file: $LOCK_FILE"
    fi
    
    # Create lock file
    echo "$$" > "$LOCK_FILE"
    
    # Check required tools
    local required_tools=("kubectl" "docker" "jq" "curl" "gh")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool '$tool' is not installed or not in PATH"
        fi
    done
    
    # Check kubectl access
    if ! kubectl cluster-info &> /dev/null; then
        error_exit "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    fi
    
    # Check Docker registry access
    if ! docker info &> /dev/null; then
        error_exit "Docker is not running or not accessible"
    fi
    
    # Check environment files
    if [[ ! -f "$PROJECT_ROOT/.env.production" ]]; then
        error_exit "Production environment file not found: $PROJECT_ROOT/.env.production"
    fi
    
    log "INFO" "✅ All prerequisites check passed"
}

# Check staging environment health
check_staging_health() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log "WARN" "Skipping staging health checks due to --skip-tests flag"
        return 0
    fi
    
    log "INFO" "Checking staging environment health..."
    
    local staging_response
    staging_response=$(curl -s -o /dev/null -w "%{http_code}" "$STAGING_URL/api/health" || echo "000")
    
    if [[ "$staging_response" != "200" ]]; then
        error_exit "Staging environment is unhealthy (HTTP $staging_response). Cannot proceed with production deployment."
    fi
    
    # Check staging database
    local db_health
    db_health=$(curl -s "$STAGING_URL/api/health" | jq -r '.database.status' 2>/dev/null || echo "unknown")
    
    if [[ "$db_health" != "healthy" ]]; then
        error_exit "Staging database is unhealthy. Cannot proceed with production deployment."
    fi
    
    log "INFO" "✅ Staging environment is healthy"
}

# Run pre-deployment tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log "WARN" "Skipping tests due to --skip-tests flag"
        return 0
    fi
    
    log "INFO" "Running pre-deployment tests..."
    
    # Backend tests
    log "INFO" "Running backend tests..."
    cd "$PROJECT_ROOT/backend"
    if ! python -m pytest tests/ --tb=short -q; then
        error_exit "Backend tests failed"
    fi
    
    # Frontend tests
    log "INFO" "Running frontend tests..."
    cd "$PROJECT_ROOT/frontend"
    if ! npm test -- --watchAll=false --verbose=false; then
        error_exit "Frontend tests failed"
    fi
    
    # Integration tests
    log "INFO" "Running integration tests..."
    cd "$PROJECT_ROOT"
    if ! python -m pytest tests/integration/ --tb=short -q; then
        error_exit "Integration tests failed"
    fi
    
    log "INFO" "✅ All tests passed"
}

# Create pre-deployment backup
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log "WARN" "Skipping backup due to --skip-backup flag"
        return 0
    fi
    
    log "INFO" "Creating pre-deployment backup..."
    
    local backup_timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="pre-deployment-$backup_timestamp"
    
    # Database backup
    kubectl create job "$backup_name" \
        --namespace="$NAMESPACE" \
        --image=postgres:15-alpine \
        --env="PGPASSWORD=$POSTGRES_PASSWORD" \
        -- bash -c "pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER bookingbridge > /backup/$backup_name.sql"
    
    # Wait for backup to complete
    if ! kubectl wait --for=condition=complete job/"$backup_name" -n "$NAMESPACE" --timeout=300s; then
        error_exit "Pre-deployment backup failed"
    fi
    
    log "INFO" "✅ Pre-deployment backup completed: $backup_name"
}

# Build and push production images
build_images() {
    log "INFO" "Building production images..."
    
    local git_sha=$(git rev-parse HEAD)
    local version="v$(date +%Y%m%d-%H%M%S)"
    local build_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    
    # Build backend image
    log "INFO" "Building backend image..."
    if [[ "$DRY_RUN" == "false" ]]; then
        docker build \
            --file "$PROJECT_ROOT/backend/Dockerfile.production" \
            --tag "$REGISTRY/$IMAGE_NAME-backend:$version" \
            --tag "$REGISTRY/$IMAGE_NAME-backend:latest" \
            --tag "$REGISTRY/$IMAGE_NAME-backend:production" \
            --build-arg BUILD_DATE="$build_date" \
            --build-arg VERSION="$version" \
            --build-arg VCS_REF="$git_sha" \
            "$PROJECT_ROOT/backend"
        
        docker push "$REGISTRY/$IMAGE_NAME-backend:$version"
        docker push "$REGISTRY/$IMAGE_NAME-backend:latest"
        docker push "$REGISTRY/$IMAGE_NAME-backend:production"
    fi
    
    # Build frontend image
    log "INFO" "Building frontend image..."
    if [[ "$DRY_RUN" == "false" ]]; then
        docker build \
            --file "$PROJECT_ROOT/frontend/Dockerfile.production" \
            --tag "$REGISTRY/$IMAGE_NAME-frontend:$version" \
            --tag "$REGISTRY/$IMAGE_NAME-frontend:latest" \
            --tag "$REGISTRY/$IMAGE_NAME-frontend:production" \
            --build-arg BUILD_DATE="$build_date" \
            --build-arg VERSION="$version" \
            --build-arg VCS_REF="$git_sha" \
            "$PROJECT_ROOT/frontend"
        
        docker push "$REGISTRY/$IMAGE_NAME-frontend:$version"
        docker push "$REGISTRY/$IMAGE_NAME-frontend:latest"
        docker push "$REGISTRY/$IMAGE_NAME-frontend:production"
    fi
    
    log "INFO" "✅ Images built and pushed successfully"
    echo "BACKEND_IMAGE=$REGISTRY/$IMAGE_NAME-backend:$version" >> "$DEPLOYMENT_LOG"
    echo "FRONTEND_IMAGE=$REGISTRY/$IMAGE_NAME-frontend:$version" >> "$DEPLOYMENT_LOG"
}

# Security scan images
security_scan() {
    log "INFO" "Running security scans on production images..."
    
    # This would typically integrate with your security scanning tools
    # Example with Trivy (if installed)
    if command -v trivy &> /dev/null; then
        log "INFO" "Running Trivy security scan..."
        
        # Scan backend image
        if ! trivy image --exit-code 1 --severity HIGH,CRITICAL "$REGISTRY/$IMAGE_NAME-backend:latest"; then
            error_exit "Critical security vulnerabilities found in backend image"
        fi
        
        # Scan frontend image
        if ! trivy image --exit-code 1 --severity HIGH,CRITICAL "$REGISTRY/$IMAGE_NAME-frontend:latest"; then
            error_exit "Critical security vulnerabilities found in frontend image"
        fi
        
        log "INFO" "✅ Security scans passed"
    else
        log "WARN" "Trivy not installed, skipping security scan"
    fi
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log "INFO" "Deploying to Kubernetes production cluster..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Update secrets
    log "INFO" "Updating production secrets..."
    if [[ "$DRY_RUN" == "false" ]]; then
        # This would typically pull from a secure secret store
        kubectl create secret generic bookingbridge-secrets \
            --namespace="$NAMESPACE" \
            --from-env-file="$PROJECT_ROOT/.env.production" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Apply configurations
    log "INFO" "Applying Kubernetes manifests..."
    if [[ "$DRY_RUN" == "false" ]]; then
        kubectl apply -f "$PROJECT_ROOT/k8s/configmap.yaml" -n "$NAMESPACE"
        kubectl apply -f "$PROJECT_ROOT/k8s/database-deployment.yaml" -n "$NAMESPACE"
        kubectl apply -f "$PROJECT_ROOT/k8s/backend-deployment.yaml" -n "$NAMESPACE"
        kubectl apply -f "$PROJECT_ROOT/k8s/frontend-deployment.yaml" -n "$NAMESPACE"
        kubectl apply -f "$PROJECT_ROOT/k8s/ingress.yaml" -n "$NAMESPACE"
        
        # Wait for deployments to be ready
        kubectl rollout status deployment/bookingbridge-backend -n "$NAMESPACE" --timeout=600s
        kubectl rollout status deployment/bookingbridge-frontend -n "$NAMESPACE" --timeout=600s
    else
        log "INFO" "[DRY RUN] Would apply Kubernetes manifests"
    fi
    
    log "INFO" "✅ Kubernetes deployment completed"
}

# Run database migrations
run_migrations() {
    log "INFO" "Running database migrations..."
    
    local migration_job="migration-$(date +%s)"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        kubectl run "$migration_job" \
            --namespace="$NAMESPACE" \
            --image="$REGISTRY/$IMAGE_NAME-backend:latest" \
            --restart=Never \
            --env="DATABASE_URL=$DATABASE_URL" \
            --command -- alembic upgrade head
        
        if ! kubectl wait --for=condition=complete job/"$migration_job" -n "$NAMESPACE" --timeout=300s; then
            error_exit "Database migrations failed"
        fi
        
        # Cleanup migration job
        kubectl delete job "$migration_job" -n "$NAMESPACE"
    else
        log "INFO" "[DRY RUN] Would run database migrations"
    fi
    
    log "INFO" "✅ Database migrations completed"
}

# Warm up application
warm_up_application() {
    log "INFO" "Warming up production application..."
    
    # Wait for application to be ready
    sleep 30
    
    # Make warm-up requests
    for i in {1..10}; do
        local response
        response=$(curl -s -o /dev/null -w "%{http_code}" "$PRODUCTION_URL/api/health" || echo "000")
        
        if [[ "$response" == "200" ]]; then
            log "INFO" "Warm-up request $i/10 successful"
        else
            log "WARN" "Warm-up request $i/10 failed (HTTP $response)"
        fi
        
        sleep 2
    done
    
    log "INFO" "✅ Application warm-up completed"
}

# Production health checks
production_health_checks() {
    log "INFO" "Running comprehensive production health checks..."
    
    # API health check
    local health_response
    health_response=$(curl -s -o /dev/null -w "%{http_code}" "$PRODUCTION_URL/api/health" || echo "000")
    
    if [[ "$health_response" != "200" ]]; then
        error_exit "Production API health check failed (HTTP $health_response)"
    fi
    
    # Database connectivity
    local db_health
    db_health=$(curl -s "$PRODUCTION_URL/api/health" | jq -r '.database.status' 2>/dev/null || echo "unknown")
    
    if [[ "$db_health" != "healthy" ]]; then
        error_exit "Production database connectivity check failed"
    fi
    
    # Redis connectivity
    local redis_health
    redis_health=$(curl -s "$PRODUCTION_URL/api/health" | jq -r '.redis.status' 2>/dev/null || echo "unknown")
    
    if [[ "$redis_health" != "healthy" ]]; then
        error_exit "Production Redis connectivity check failed"
    fi
    
    # Performance check
    local response_time
    response_time=$(curl -s -w "%{time_total}" -o /dev/null "$PRODUCTION_URL/api/v1/businesses" || echo "0")
    
    if (( $(echo "$response_time > 2.0" | bc -l) )); then
        log "WARN" "Response time slower than expected: ${response_time}s"
    else
        log "INFO" "Response time within acceptable range: ${response_time}s"
    fi
    
    log "INFO" "✅ All production health checks passed"
}

# Rollback function
rollback_deployment() {
    log "INFO" "🚨 Initiating emergency rollback..."
    
    # Rollback deployments
    kubectl rollout undo deployment/bookingbridge-backend -n "$NAMESPACE"
    kubectl rollout undo deployment/bookingbridge-frontend -n "$NAMESPACE"
    
    # Wait for rollback to complete
    kubectl rollout status deployment/bookingbridge-backend -n "$NAMESPACE" --timeout=300s
    kubectl rollout status deployment/bookingbridge-frontend -n "$NAMESPACE" --timeout=300s
    
    log "INFO" "✅ Emergency rollback completed"
}

# Main deployment function
main_deployment() {
    log "INFO" "🚀 Starting BookingBridge production deployment..."
    log "INFO" "Deployment log: $DEPLOYMENT_LOG"
    
    if [[ "$ROLLBACK" == "true" ]]; then
        rollback_deployment
        return 0
    fi
    
    check_prerequisites
    check_staging_health
    run_tests
    create_backup
    build_images
    security_scan
    deploy_to_kubernetes
    run_migrations
    warm_up_application
    production_health_checks
    
    log "INFO" "🎉 Production deployment completed successfully!"
    log "INFO" "Production URL: $PRODUCTION_URL"
    log "INFO" "Deployment log: $DEPLOYMENT_LOG"
}

# Parse arguments and run main function
parse_args "$@"
main_deployment