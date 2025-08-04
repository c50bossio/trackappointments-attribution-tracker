#!/bin/bash

# BookingBridge Production Readiness Assessment
# Comprehensive checklist to verify production deployment readiness
#
# Usage: ./production-readiness-check.sh [options]
# Options:
#   --fix-issues      Automatically fix issues where possible
#   --verbose         Show detailed output
#   --export-report   Export results to production-readiness-report.json
#   --help            Show this help message

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Options
FIX_ISSUES=false
VERBOSE=false
EXPORT_REPORT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Checklist results
declare -A CHECKS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix-issues)
                FIX_ISSUES=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --export-report)
                EXPORT_REPORT=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
BookingBridge Production Readiness Assessment

Usage: $0 [options]

Options:
    --fix-issues      Automatically fix issues where possible
    --verbose         Show detailed output
    --export-report   Export results to production-readiness-report.json  
    --help            Show this help message

This script checks:
    ✓ Environment configuration
    ✓ Security settings
    ✓ Docker configuration
    ✓ Kubernetes manifests
    ✓ Database setup
    ✓ Monitoring configuration
    ✓ SSL certificates
    ✓ Backup procedures
    ✓ CI/CD pipeline
    ✓ Documentation completeness

EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Check result recording
record_check() {
    local name=$1
    local status=$2  # PASS, FAIL, WARN
    local message=$3
    
    CHECKS["$name"]="$status:$message"
    ((TOTAL_CHECKS++))
    
    case $status in
        "PASS")
            ((PASSED_CHECKS++))
            log_info "$message"
            ;;
        "WARN")
            ((WARNING_CHECKS++))
            log_warn "$message"
            ;;
        "FAIL")
            ((FAILED_CHECKS++))
            log_error "$message"
            ;;
    esac
}

# Environment configuration checks
check_environment_config() {
    echo "🔧 Checking Environment Configuration..."
    
    # Check .env.production exists
    if [[ -f "$PROJECT_ROOT/.env.production" ]]; then
        record_check "env_file" "PASS" "Production environment file exists"
        
        # Check for placeholder values
        local placeholders=$(grep -E "(your_|generate_|placeholder)" "$PROJECT_ROOT/.env.production" | wc -l)
        if [[ "$placeholders" -gt 0 ]]; then
            record_check "env_placeholders" "WARN" "$placeholders placeholder values found in .env.production"
        else
            record_check "env_placeholders" "PASS" "No placeholder values in environment file"
        fi
        
        # Check required variables
        local required_vars=(
            "DATABASE_URL"
            "REDIS_URL"
            "SECRET_KEY"
            "JWT_PRIVATE_KEY_PATH"
            "FACEBOOK_APP_SECRET"
            "GOOGLE_ADS_CLIENT_SECRET"
            "SENDGRID_API_KEY"
        )
        
        local missing_vars=0
        for var in "${required_vars[@]}"; do
            if ! grep -q "^$var=" "$PROJECT_ROOT/.env.production"; then
                ((missing_vars++))
            fi
        done
        
        if [[ "$missing_vars" -eq 0 ]]; then
            record_check "env_required_vars" "PASS" "All required environment variables present"
        else
            record_check "env_required_vars" "FAIL" "$missing_vars required environment variables missing"
        fi
    else
        record_check "env_file" "FAIL" "Production environment file missing"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_debug "Creating .env.production from template..."
            if [[ -f "$PROJECT_ROOT/.env.production.template" ]]; then
                cp "$PROJECT_ROOT/.env.production.template" "$PROJECT_ROOT/.env.production"
                log_info "Created .env.production from template - please configure values"
            fi
        fi
    fi
}

# Security configuration checks
check_security_config() {
    echo "🔐 Checking Security Configuration..."
    
    # Check JWT keys exist
    if [[ -f "$PROJECT_ROOT/backend/keys/jwt_private_key.pem" ]] && [[ -f "$PROJECT_ROOT/backend/keys/jwt_public_key.pem" ]]; then
        record_check "jwt_keys" "PASS" "JWT RSA key pair exists"
        
        # Check key permissions
        local private_perms=$(stat -c "%a" "$PROJECT_ROOT/backend/keys/jwt_private_key.pem" 2>/dev/null || echo "000")
        if [[ "$private_perms" == "600" ]]; then
            record_check "jwt_key_perms" "PASS" "JWT private key has secure permissions"
        else
            record_check "jwt_key_perms" "WARN" "JWT private key permissions should be 600"
            
            if [[ "$FIX_ISSUES" == "true" ]]; then
                chmod 600 "$PROJECT_ROOT/backend/keys/jwt_private_key.pem"
                log_debug "Fixed JWT private key permissions"
            fi
        fi
    else
        record_check "jwt_keys" "FAIL" "JWT RSA keys missing"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            log_debug "Generating JWT keys..."
            mkdir -p "$PROJECT_ROOT/backend/keys"
            ./scripts/generate-production-secrets.sh --output-dir "$PROJECT_ROOT/backend/keys"
        fi
    fi
    
    # Check SSL certificate configuration
    if [[ -f "$PROJECT_ROOT/nginx/conf.d/bookingbridge.conf" ]]; then
        if grep -q "ssl_certificate" "$PROJECT_ROOT/nginx/conf.d/bookingbridge.conf"; then
            record_check "ssl_config" "PASS" "SSL configuration present in Nginx"
        else
            record_check "ssl_config" "WARN" "SSL configuration missing in Nginx"
        fi
    else
        record_check "ssl_config" "WARN" "Nginx configuration file missing"
    fi
    
    # Check security headers in Nginx config
    if [[ -f "$PROJECT_ROOT/nginx/nginx.production.conf" ]]; then
        local security_headers=(
            "Strict-Transport-Security"
            "X-Frame-Options"
            "X-Content-Type-Options"
            "Content-Security-Policy"
        )
        
        local missing_headers=0
        for header in "${security_headers[@]}"; do
            if ! grep -q "$header" "$PROJECT_ROOT/nginx/nginx.production.conf"; then
                ((missing_headers++))
            fi
        done
        
        if [[ "$missing_headers" -eq 0 ]]; then
            record_check "security_headers" "PASS" "All security headers configured"
        else
            record_check "security_headers" "WARN" "$missing_headers security headers missing"
        fi
    fi
}

# Docker configuration checks
check_docker_config() {
    echo "🐳 Checking Docker Configuration..."
    
    # Check production Dockerfiles exist
    if [[ -f "$PROJECT_ROOT/backend/Dockerfile.production" ]] && [[ -f "$PROJECT_ROOT/frontend/Dockerfile.production" ]]; then
        record_check "docker_files" "PASS" "Production Dockerfiles exist"
        
        # Check for multi-stage builds
        if grep -q "FROM.*AS.*builder" "$PROJECT_ROOT/backend/Dockerfile.production"; then
            record_check "docker_multistage" "PASS" "Multi-stage build configured"
        else
            record_check "docker_multistage" "WARN" "Consider using multi-stage builds for smaller images"
        fi
        
        # Check for non-root user
        if grep -q "USER.*[^0]" "$PROJECT_ROOT/backend/Dockerfile.production"; then
            record_check "docker_nonroot" "PASS" "Non-root user configured in Docker"
        else
            record_check "docker_nonroot" "FAIL" "Docker containers should run as non-root user"
        fi
    else
        record_check "docker_files" "FAIL" "Production Dockerfiles missing"
    fi
    
    # Check docker-compose.production.yml
    if [[ -f "$PROJECT_ROOT/docker-compose.production.yml" ]]; then
        record_check "docker_compose" "PASS" "Production Docker Compose file exists"
        
        # Check for health checks
        if grep -q "healthcheck:" "$PROJECT_ROOT/docker-compose.production.yml"; then
            record_check "docker_healthchecks" "PASS" "Health checks configured in Docker Compose"
        else
            record_check "docker_healthchecks" "WARN" "Health checks missing in Docker Compose"
        fi
        
        # Check for resource limits
        if grep -q "deploy:" "$PROJECT_ROOT/docker-compose.production.yml"; then
            record_check "docker_limits" "PASS" "Resource limits configured"
        else
            record_check "docker_limits" "WARN" "Resource limits missing"
        fi
    else
        record_check "docker_compose" "FAIL" "Production Docker Compose file missing"
    fi
}

# Kubernetes configuration checks
check_kubernetes_config() {
    echo "☸️ Checking Kubernetes Configuration..."
    
    # Check manifest files exist
    local k8s_files=(
        "namespace.yaml"
        "configmap.yaml" 
        "secrets.yaml"
        "backend-deployment.yaml"
        "frontend-deployment.yaml"
        "database-deployment.yaml"
        "ingress.yaml"
    )
    
    local missing_files=0
    for file in "${k8s_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/k8s/$file" ]]; then
            ((missing_files++))
            log_debug "Missing K8s file: $file"
        fi
    done
    
    if [[ "$missing_files" -eq 0 ]]; then
        record_check "k8s_manifests" "PASS" "All Kubernetes manifests exist"
    else
        record_check "k8s_manifests" "WARN" "$missing_files Kubernetes manifest files missing"
    fi
    
    # Check for security contexts
    if [[ -f "$PROJECT_ROOT/k8s/backend-deployment.yaml" ]]; then
        if grep -q "securityContext:" "$PROJECT_ROOT/k8s/backend-deployment.yaml"; then
            record_check "k8s_security" "PASS" "Security contexts configured"
        else
            record_check "k8s_security" "WARN" "Security contexts missing"
        fi
        
        # Check for resource limits
        if grep -q "resources:" "$PROJECT_ROOT/k8s/backend-deployment.yaml"; then
            record_check "k8s_resources" "PASS" "Resource limits configured"
        else
            record_check "k8s_resources" "WARN" "Resource limits missing"
        fi
        
        # Check for HPA
        if grep -q "HorizontalPodAutoscaler" "$PROJECT_ROOT/k8s/backend-deployment.yaml"; then
            record_check "k8s_hpa" "PASS" "Horizontal Pod Autoscaler configured"
        else
            record_check "k8s_hpa" "WARN" "Horizontal Pod Autoscaler missing"
        fi
    fi
}

# Database configuration checks
check_database_config() {
    echo "🗄️ Checking Database Configuration..."
    
    # Check for database init scripts
    if [[ -f "$PROJECT_ROOT/backend/init.sql" ]] || [[ -d "$PROJECT_ROOT/backend/init.sql" ]]; then
        record_check "db_init" "PASS" "Database initialization scripts exist"
    else
        record_check "db_init" "WARN" "Database initialization scripts missing"
    fi
    
    # Check for Alembic migrations
    if [[ -d "$PROJECT_ROOT/backend/alembic/versions" ]]; then
        local migration_count=$(find "$PROJECT_ROOT/backend/alembic/versions" -name "*.py" | wc -l)
        if [[ "$migration_count" -gt 0 ]]; then
            record_check "db_migrations" "PASS" "$migration_count database migrations found"
        else
            record_check "db_migrations" "WARN" "No database migrations found"
        fi
    else
        record_check "db_migrations" "FAIL" "Alembic migrations directory missing"
    fi
    
    # Check for backup configuration
    if [[ -f "$PROJECT_ROOT/database/backup/backup-database.sh" ]]; then
        record_check "db_backup" "PASS" "Database backup script exists"
        
        # Check if script is executable
        if [[ -x "$PROJECT_ROOT/database/backup/backup-database.sh" ]]; then
            record_check "db_backup_exec" "PASS" "Database backup script is executable"
        else
            record_check "db_backup_exec" "WARN" "Database backup script not executable"
            
            if [[ "$FIX_ISSUES" == "true" ]]; then
                chmod +x "$PROJECT_ROOT/database/backup/backup-database.sh"
                log_debug "Made backup script executable"
            fi
        fi
    else
        record_check "db_backup" "WARN" "Database backup script missing"
    fi
    
    # Check PostgreSQL production config
    if [[ -f "$PROJECT_ROOT/database/production/postgresql.conf" ]]; then
        record_check "db_config" "PASS" "PostgreSQL production configuration exists"
    else
        record_check "db_config" "WARN" "PostgreSQL production configuration missing"
    fi
}

# Monitoring configuration checks
check_monitoring_config() {
    echo "📊 Checking Monitoring Configuration..."
    
    # Check Prometheus configuration
    if [[ -f "$PROJECT_ROOT/monitoring/prometheus/prometheus.yml" ]]; then
        record_check "prometheus_config" "PASS" "Prometheus configuration exists"
        
        # Check for application scrape configs
        if grep -q "bookingbridge-backend" "$PROJECT_ROOT/monitoring/prometheus/prometheus.yml"; then
            record_check "prometheus_scraping" "PASS" "Application scraping configured"
        else
            record_check "prometheus_scraping" "WARN" "Application scraping not configured"
        fi
    else
        record_check "prometheus_config" "FAIL" "Prometheus configuration missing"
    fi
    
    # Check Grafana dashboards
    if [[ -d "$PROJECT_ROOT/monitoring/grafana/dashboards" ]]; then
        local dashboard_count=$(find "$PROJECT_ROOT/monitoring/grafana/dashboards" -name "*.json" | wc -l)
        if [[ "$dashboard_count" -gt 0 ]]; then
            record_check "grafana_dashboards" "PASS" "$dashboard_count Grafana dashboards found"
        else
            record_check "grafana_dashboards" "WARN" "No Grafana dashboards found"
        fi
    else
        record_check "grafana_dashboards" "WARN" "Grafana dashboards directory missing"
    fi
    
    # Check alert rules
    if [[ -f "$PROJECT_ROOT/monitoring/prometheus/alerts/bookingbridge-alerts.yml" ]]; then
        record_check "alert_rules" "PASS" "Prometheus alert rules exist"
    else
        record_check "alert_rules" "WARN" "Prometheus alert rules missing"
    fi
    
    # Check health check script
    if [[ -f "$PROJECT_ROOT/scripts/health-check-production.sh" ]]; then
        record_check "health_check_script" "PASS" "Health check script exists"
        
        if [[ -x "$PROJECT_ROOT/scripts/health-check-production.sh" ]]; then
            record_check "health_check_exec" "PASS" "Health check script is executable"
        else
            record_check "health_check_exec" "WARN" "Health check script not executable"
            
            if [[ "$FIX_ISSUES" == "true" ]]; then
                chmod +x "$PROJECT_ROOT/scripts/health-check-production.sh"
                log_debug "Made health check script executable"
            fi
        fi
    else
        record_check "health_check_script" "FAIL" "Health check script missing"
    fi
}

# CI/CD pipeline checks
check_cicd_pipeline() {
    echo "🚀 Checking CI/CD Pipeline..."
    
    # Check GitHub Actions workflows
    local workflow_files=(
        "ci.yml"
        "deploy-staging.yml"
        "deploy-production.yml"
    )
    
    local missing_workflows=0
    for workflow in "${workflow_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/.github/workflows/$workflow" ]]; then
            ((missing_workflows++))
        fi
    done
    
    if [[ "$missing_workflows" -eq 0 ]]; then
        record_check "cicd_workflows" "PASS" "All CI/CD workflow files exist"
    else
        record_check "cicd_workflows" "WARN" "$missing_workflows CI/CD workflow files missing"
    fi
    
    # Check deployment script
    if [[ -f "$PROJECT_ROOT/scripts/deploy-production.sh" ]]; then
        record_check "deploy_script" "PASS" "Production deployment script exists"
        
        if [[ -x "$PROJECT_ROOT/scripts/deploy-production.sh" ]]; then
            record_check "deploy_script_exec" "PASS" "Deployment script is executable"
        else
            record_check "deploy_script_exec" "WARN" "Deployment script not executable"
            
            if [[ "$FIX_ISSUES" == "true" ]]; then
                chmod +x "$PROJECT_ROOT/scripts/deploy-production.sh"
                log_debug "Made deployment script executable"
            fi
        fi
    else
        record_check "deploy_script" "FAIL" "Production deployment script missing"
    fi
}

# Documentation checks
check_documentation() {
    echo "📚 Checking Documentation..."
    
    # Check main documentation files
    local doc_files=(
        "README.md"
        "CLAUDE.md"
        "docs/PRODUCTION_DEPLOYMENT_GUIDE.md"
    )
    
    local missing_docs=0
    for doc in "${doc_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$doc" ]]; then
            ((missing_docs++))
        fi
    done
    
    if [[ "$missing_docs" -eq 0 ]]; then
        record_check "documentation" "PASS" "All key documentation files exist"
    else
        record_check "documentation" "WARN" "$missing_docs documentation files missing"
    fi
    
    # Check API documentation
    if grep -q "docs" "$PROJECT_ROOT/backend/main.py" 2>/dev/null; then
        record_check "api_docs" "PASS" "API documentation configured"
    else
        record_check "api_docs" "WARN" "API documentation not configured"
    fi
}

# Test configuration checks
check_test_config() {
    echo "🧪 Checking Test Configuration..."
    
    # Check backend tests
    if [[ -d "$PROJECT_ROOT/backend/tests" ]]; then
        local test_count=$(find "$PROJECT_ROOT/backend/tests" -name "test_*.py" -o -name "*_test.py" | wc -l)
        if [[ "$test_count" -gt 0 ]]; then
            record_check "backend_tests" "PASS" "$test_count backend test files found"
        else
            record_check "backend_tests" "WARN" "No backend test files found"
        fi
    else
        record_check "backend_tests" "WARN" "Backend tests directory missing"
    fi
    
    # Check frontend tests
    if [[ -f "$PROJECT_ROOT/frontend/package.json" ]]; then
        if grep -q "\"test\":" "$PROJECT_ROOT/frontend/package.json"; then
            record_check "frontend_tests" "PASS" "Frontend test script configured"
        else
            record_check "frontend_tests" "WARN" "Frontend test script not configured"
        fi
    fi
    
    # Check pytest configuration
    if [[ -f "$PROJECT_ROOT/backend/pytest.ini" ]] || [[ -f "$PROJECT_ROOT/backend/pyproject.toml" ]]; then
        record_check "pytest_config" "PASS" "Pytest configuration exists"
    else
        record_check "pytest_config" "WARN" "Pytest configuration missing"
    fi
}

# Generate report
generate_report() {
    local timestamp=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
    local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    echo
    echo "=============================================="
    echo "BookingBridge Production Readiness Report"
    echo "=============================================="
    echo "Generated: $timestamp"
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Warnings: $WARNING_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    echo "Score: $score/100"
    echo
    
    if [[ "$score" -ge 90 ]]; then
        echo -e "Status: ${GREEN}PRODUCTION READY${NC} ✅"
        echo "Your BookingBridge deployment is ready for production!"
    elif [[ "$score" -ge 80 ]]; then
        echo -e "Status: ${YELLOW}MOSTLY READY${NC} ⚠️"
        echo "A few issues should be addressed before production deployment."
    elif [[ "$score" -ge 70 ]]; then
        echo -e "Status: ${YELLOW}NEEDS WORK${NC} ⚠️"
        echo "Several issues need to be resolved before production deployment."
    else
        echo -e "Status: ${RED}NOT READY${NC} ❌"
        echo "Significant work needed before production deployment."
    fi
    
    echo
    echo "Detailed Results:"
    echo "----------------------------------------------"
    
    for check in "${!CHECKS[@]}"; do
        local status=$(echo "${CHECKS[$check]}" | cut -d: -f1)
        local message=$(echo "${CHECKS[$check]}" | cut -d: -f2-)
        
        case $status in
            "PASS") echo -e "${GREEN}✓${NC} $check: $message" ;;
            "WARN") echo -e "${YELLOW}!${NC} $check: $message" ;;
            "FAIL") echo -e "${RED}✗${NC} $check: $message" ;;
        esac
    done
    
    echo "=============================================="
    
    # Export JSON report if requested
    if [[ "$EXPORT_REPORT" == "true" ]]; then
        local report_file="$PROJECT_ROOT/production-readiness-report.json"
        
        echo "{" > "$report_file"
        echo "  \"timestamp\": \"$timestamp\"," >> "$report_file"
        echo "  \"score\": $score," >> "$report_file"
        echo "  \"total_checks\": $TOTAL_CHECKS," >> "$report_file"
        echo "  \"passed_checks\": $PASSED_CHECKS," >> "$report_file"
        echo "  \"warning_checks\": $WARNING_CHECKS," >> "$report_file"
        echo "  \"failed_checks\": $FAILED_CHECKS," >> "$report_file"
        echo "  \"checks\": {" >> "$report_file"
        
        local first=true
        for check in "${!CHECKS[@]}"; do
            if [[ "$first" == "false" ]]; then
                echo "," >> "$report_file"
            fi
            echo -n "    \"$check\": \"${CHECKS[$check]}\"" >> "$report_file"
            first=false
        done
        
        echo "" >> "$report_file"
        echo "  }" >> "$report_file"
        echo "}" >> "$report_file"
        
        echo "Report exported to: $report_file"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo "🔍 BookingBridge Production Readiness Assessment"
    echo "================================================="
    echo
    
    check_environment_config
    echo
    check_security_config
    echo
    check_docker_config
    echo
    check_kubernetes_config
    echo
    check_database_config
    echo
    check_monitoring_config
    echo
    check_cicd_pipeline
    echo
    check_documentation
    echo
    check_test_config
    echo
    
    generate_report
}

# Run main function
main "$@"