#!/bin/bash

# BookingBridge Production Health Check Script
# Comprehensive monitoring and health validation for production environment
#
# Usage: ./health-check-production.sh [options]
# Options:
#   --url URL           Production URL to check (default: https://bookingbridge.com)
#   --timeout SECONDS   Request timeout in seconds (default: 30)
#   --verbose           Show detailed output
#   --json              Output results in JSON format
#   --continuous        Run continuous monitoring (every 60 seconds)
#   --alert-webhook URL Webhook URL for sending alerts
#   --help              Show this help message

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
PRODUCTION_URL="https://bookingbridge.com"
TIMEOUT=30
VERBOSE=false
JSON_OUTPUT=false
CONTINUOUS=false
ALERT_WEBHOOK=""

# Health check thresholds
MAX_RESPONSE_TIME=2.0
MIN_UPTIME_PERCENTAGE=99.9
MAX_ERROR_RATE=1.0
MAX_MEMORY_USAGE=80
MAX_CPU_USAGE=80
MIN_DISK_SPACE=20

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check results
declare -A HEALTH_RESULTS

# Logging function
log() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        local level=$1
        shift
        local message="$*"
        
        case $level in
            "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
            "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
            "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
            "DEBUG") [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        esac
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                PRODUCTION_URL="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --continuous)
                CONTINUOUS=true
                shift
                ;;
            --alert-webhook)
                ALERT_WEBHOOK="$2"
                shift 2
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

# Show help
show_help() {
    cat << EOF
BookingBridge Production Health Check Script

Usage: $0 [options]

Options:
    --url URL           Production URL to check (default: https://bookingbridge.com)
    --timeout SECONDS   Request timeout in seconds (default: 30)
    --verbose           Show detailed output
    --json              Output results in JSON format
    --continuous        Run continuous monitoring (every 60 seconds)
    --alert-webhook URL Webhook URL for sending alerts
    --help              Show this help message

Examples:
    $0                                    # Basic health check
    $0 --verbose                          # Detailed health check
    $0 --json                            # JSON output
    $0 --continuous                      # Continuous monitoring
    $0 --url https://staging.bookingbridge.com  # Check staging

Health Checks:
    ✓ API endpoint availability
    ✓ Database connectivity
    ✓ Redis connectivity
    ✓ Response time performance
    ✓ SSL certificate validity
    ✓ External service dependencies
    ✓ System resource usage
    ✓ Application metrics

EOF
}

# Make HTTP request with error handling
make_request() {
    local url=$1
    local expected_code=${2:-200}
    local method=${3:-GET}
    
    local response
    local http_code
    local response_time
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}:RESPONSETIME:%{time_total}" \
        --max-time "$TIMEOUT" \
        -X "$method" \
        -H "User-Agent: BookingBridge-HealthCheck/1.0" \
        "$url" 2>/dev/null || echo "HTTPSTATUS:000:RESPONSETIME:0")
    
    http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    response_time=$(echo "$response" | grep -o "RESPONSETIME:[0-9.]*" | cut -d: -f2)
    local body=$(echo "$response" | sed -E 's/HTTPSTATUS:[0-9]*:RESPONSETIME:[0-9.]*$//')
    
    echo "${http_code}:${response_time}:${body}"
}

# Check API health endpoint
check_api_health() {
    log "DEBUG" "Checking API health endpoint..."
    
    local result
    result=$(make_request "$PRODUCTION_URL/api/health")
    
    local http_code=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    local body=$(echo "$result" | cut -d: -f3-)
    
    if [[ "$http_code" == "200" ]]; then
        HEALTH_RESULTS["api_status"]="healthy"
        HEALTH_RESULTS["api_response_time"]="$response_time"
        
        # Parse health response for detailed status
        if command -v jq &> /dev/null && [[ -n "$body" ]]; then
            local db_status=$(echo "$body" | jq -r '.database.status // "unknown"' 2>/dev/null)
            local redis_status=$(echo "$body" | jq -r '.redis.status // "unknown"' 2>/dev/null)
            
            HEALTH_RESULTS["database_status"]="$db_status"
            HEALTH_RESULTS["redis_status"]="$redis_status"
        fi
        
        log "INFO" "✅ API health check passed (${response_time}s)"
    else
        HEALTH_RESULTS["api_status"]="unhealthy"
        HEALTH_RESULTS["api_response_time"]="$response_time"
        HEALTH_RESULTS["api_error_code"]="$http_code"
        
        log "ERROR" "❌ API health check failed (HTTP $http_code)"
    fi
}

# Check frontend health
check_frontend_health() {
    log "DEBUG" "Checking frontend health..."
    
    local result
    result=$(make_request "$PRODUCTION_URL/health")
    
    local http_code=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    if [[ "$http_code" == "200" ]]; then
        HEALTH_RESULTS["frontend_status"]="healthy"
        HEALTH_RESULTS["frontend_response_time"]="$response_time"
        log "INFO" "✅ Frontend health check passed (${response_time}s)"
    else
        HEALTH_RESULTS["frontend_status"]="unhealthy"
        HEALTH_RESULTS["frontend_response_time"]="$response_time"
        HEALTH_RESULTS["frontend_error_code"]="$http_code"
        log "ERROR" "❌ Frontend health check failed (HTTP $http_code)"
    fi
}

# Check SSL certificate
check_ssl_certificate() {
    log "DEBUG" "Checking SSL certificate..."
    
    local domain=$(echo "$PRODUCTION_URL" | sed -E 's|https?://([^/]+).*|\1|')
    local cert_info
    
    cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
        openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$cert_info" ]]; then
        local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        local expiry_date=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local days_until_expiry=$(( (expiry_date - current_date) / 86400 ))
        
        HEALTH_RESULTS["ssl_status"]="valid"
        HEALTH_RESULTS["ssl_days_until_expiry"]="$days_until_expiry"
        
        if [[ "$days_until_expiry" -lt 30 ]]; then
            log "WARN" "⚠️ SSL certificate expires in $days_until_expiry days"
        else
            log "INFO" "✅ SSL certificate valid ($days_until_expiry days remaining)"
        fi
    else
        HEALTH_RESULTS["ssl_status"]="invalid"
        log "ERROR" "❌ SSL certificate check failed"
    fi
}

# Check database connectivity
check_database() {
    log "DEBUG" "Checking database connectivity..."
    
    local result
    result=$(make_request "$PRODUCTION_URL/api/v1/businesses" "" "GET")
    
    local http_code=$(echo "$result" | cut -d: -f1)
    local response_time=$(echo "$result" | cut -d: -f2)
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "401" ]]; then
        # 401 is acceptable as it means the endpoint is working but requires auth
        HEALTH_RESULTS["database_connectivity"]="healthy"
        HEALTH_RESULTS["database_response_time"]="$response_time"
        log "INFO" "✅ Database connectivity check passed"
    else
        HEALTH_RESULTS["database_connectivity"]="unhealthy"
        HEALTH_RESULTS["database_response_time"]="$response_time"
        log "ERROR" "❌ Database connectivity check failed (HTTP $http_code)"
    fi
}

# Check external dependencies
check_external_dependencies() {
    log "DEBUG" "Checking external service dependencies..."
    
    local services=(
        "https://graph.facebook.com/v18.0/me:Facebook API"
        "https://googleads.googleapis.com/v16/customers:Google Ads API"
        "https://connect.squareup.com/v2/locations:Square API"
    )
    
    local healthy_services=0
    local total_services=${#services[@]}
    
    for service in "${services[@]}"; do
        local url=$(echo "$service" | cut -d: -f1-2)
        local name=$(echo "$service" | cut -d: -f3)
        
        local result
        result=$(make_request "$url")
        local http_code=$(echo "$result" | cut -d: -f1)
        
        # These APIs typically return 401/403 when no auth is provided, which is acceptable
        if [[ "$http_code" =~ ^(200|401|403)$ ]]; then
            ((healthy_services++))
            log "DEBUG" "✅ $name is reachable"
        else
            log "WARN" "⚠️ $name may be unreachable (HTTP $http_code)"
        fi
    done
    
    local health_percentage=$((healthy_services * 100 / total_services))
    HEALTH_RESULTS["external_services_health"]="$health_percentage"
    
    if [[ "$health_percentage" -ge 80 ]]; then
        log "INFO" "✅ External services check passed ($healthy_services/$total_services healthy)"
    else
        log "WARN" "⚠️ Some external services may be unreachable ($healthy_services/$total_services healthy)"
    fi
}

# Check performance metrics
check_performance() {
    log "DEBUG" "Checking performance metrics..."
    
    # Check multiple endpoints for average response time
    local endpoints=(
        "/api/health"
        "/health"
        "/"
    )
    
    local total_time=0
    local successful_requests=0
    
    for endpoint in "${endpoints[@]}"; do
        local result
        result=$(make_request "$PRODUCTION_URL$endpoint")
        local http_code=$(echo "$result" | cut -d: -f1)
        local response_time=$(echo "$result" | cut -d: -f2)
        
        if [[ "$http_code" == "200" ]]; then
            total_time=$(echo "$total_time + $response_time" | bc)
            ((successful_requests++))
        fi
    done
    
    if [[ "$successful_requests" -gt 0 ]]; then
        local avg_response_time=$(echo "scale=3; $total_time / $successful_requests" | bc)
        HEALTH_RESULTS["avg_response_time"]="$avg_response_time"
        
        if (( $(echo "$avg_response_time > $MAX_RESPONSE_TIME" | bc -l) )); then
            log "WARN" "⚠️ Average response time is high: ${avg_response_time}s (threshold: ${MAX_RESPONSE_TIME}s)"
        else
            log "INFO" "✅ Performance check passed (avg response time: ${avg_response_time}s)"
        fi
    else
        HEALTH_RESULTS["avg_response_time"]="N/A"
        log "ERROR" "❌ Could not measure performance (no successful requests)"
    fi
}

# Check Kubernetes cluster health (if accessible)
check_kubernetes_health() {
    if command -v kubectl &> /dev/null; then
        log "DEBUG" "Checking Kubernetes cluster health..."
        
        # Check if we can connect to the cluster
        if kubectl cluster-info &> /dev/null; then
            # Check pod status
            local unhealthy_pods
            unhealthy_pods=$(kubectl get pods -n bookingbridge --no-headers | \
                grep -v "Running\|Completed" | wc -l)
            
            HEALTH_RESULTS["k8s_unhealthy_pods"]="$unhealthy_pods"
            
            if [[ "$unhealthy_pods" -eq 0 ]]; then
                log "INFO" "✅ All Kubernetes pods are healthy"
            else
                log "WARN" "⚠️ $unhealthy_pods unhealthy pods found in Kubernetes"
            fi
            
            # Check resource usage
            local cpu_usage
            local memory_usage
            
            cpu_usage=$(kubectl top nodes --no-headers 2>/dev/null | \
                awk '{sum+=$3} END {print sum/NR}' || echo "N/A")
            memory_usage=$(kubectl top nodes --no-headers 2>/dev/null | \
                awk '{sum+=$5} END {print sum/NR}' || echo "N/A")
            
            HEALTH_RESULTS["k8s_cpu_usage"]="$cpu_usage"
            HEALTH_RESULTS["k8s_memory_usage"]="$memory_usage"
        else
            HEALTH_RESULTS["k8s_status"]="unreachable"
            log "DEBUG" "Kubernetes cluster not accessible"
        fi
    else
        log "DEBUG" "kubectl not available, skipping Kubernetes checks"
    fi
}

# Send alert webhook
send_alert() {
    local message=$1
    local severity=${2:-"warning"}
    
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local payload
        payload=$(cat << EOF
{
    "text": "BookingBridge Health Alert",
    "attachments": [
        {
            "color": "danger",
            "fields": [
                {
                    "title": "Severity",
                    "value": "$severity",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -u +'%Y-%m-%d %H:%M:%S UTC')",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$ALERT_WEBHOOK" > /dev/null || true
    fi
}

# Calculate overall health score
calculate_health_score() {
    local score=100
    
    # API health (25 points)
    if [[ "${HEALTH_RESULTS[api_status]}" != "healthy" ]]; then
        score=$((score - 25))
    fi
    
    # Frontend health (20 points)
    if [[ "${HEALTH_RESULTS[frontend_status]}" != "healthy" ]]; then
        score=$((score - 20))
    fi
    
    # Database connectivity (25 points)
    if [[ "${HEALTH_RESULTS[database_connectivity]}" != "healthy" ]]; then
        score=$((score - 25))
    fi
    
    # SSL certificate (10 points)
    if [[ "${HEALTH_RESULTS[ssl_status]}" != "valid" ]]; then
        score=$((score - 10))
    fi
    
    # Performance (10 points)
    local response_time="${HEALTH_RESULTS[avg_response_time]}"
    if [[ "$response_time" != "N/A" ]] && (( $(echo "$response_time > $MAX_RESPONSE_TIME" | bc -l) )); then
        score=$((score - 10))
    fi
    
    # External services (10 points)
    local ext_health="${HEALTH_RESULTS[external_services_health]}"
    if [[ "$ext_health" -lt 80 ]]; then
        score=$((score - 10))
    fi
    
    HEALTH_RESULTS["overall_health_score"]="$score"
}

# Output results
output_results() {
    calculate_health_score
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        # JSON output
        echo "{"
        echo "  \"timestamp\": \"$(date -u +'%Y-%m-%d %H:%M:%S UTC')\","
        echo "  \"overall_health_score\": ${HEALTH_RESULTS[overall_health_score]},"
        echo "  \"checks\": {"
        
        local first=true
        for key in "${!HEALTH_RESULTS[@]}"; do
            if [[ "$key" != "overall_health_score" ]]; then
                if [[ "$first" == "false" ]]; then
                    echo ","
                fi
                echo -n "    \"$key\": \"${HEALTH_RESULTS[$key]}\""
                first=false
            fi
        done
        
        echo ""
        echo "  }"
        echo "}"
    else
        # Human-readable output
        local score="${HEALTH_RESULTS[overall_health_score]}"
        echo
        echo "=========================================="
        echo "BookingBridge Production Health Summary"
        echo "=========================================="
        echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
        echo "Overall Health Score: $score/100"
        
        if [[ "$score" -ge 90 ]]; then
            echo -e "Status: ${GREEN}HEALTHY${NC} 🟢"
        elif [[ "$score" -ge 70 ]]; then
            echo -e "Status: ${YELLOW}DEGRADED${NC} 🟡"
        else
            echo -e "Status: ${RED}UNHEALTHY${NC} 🔴"
        fi
        
        echo
        echo "Detailed Results:"
        echo "------------------------------------------"
        
        for key in "${!HEALTH_RESULTS[@]}"; do
            if [[ "$key" != "overall_health_score" ]]; then
                echo "$key: ${HEALTH_RESULTS[$key]}"
            fi
        done
        
        echo "=========================================="
    fi
    
    # Send alert if health score is low
    if [[ "${HEALTH_RESULTS[overall_health_score]}" -lt 80 ]]; then
        send_alert "Production health score is low: ${HEALTH_RESULTS[overall_health_score]}/100" "critical"
    fi
}

# Run all health checks
run_health_checks() {
    local timestamp=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
    
    log "INFO" "🏥 Starting production health checks at $timestamp"
    log "INFO" "Target URL: $PRODUCTION_URL"
    
    # Clear previous results
    HEALTH_RESULTS=()
    
    # Run all checks
    check_api_health
    check_frontend_health
    check_ssl_certificate
    check_database
    check_external_dependencies
    check_performance
    check_kubernetes_health
    
    # Output results
    output_results
}

# Main function
main() {
    parse_args "$@"
    
    if [[ "$CONTINUOUS" == "true" ]]; then
        log "INFO" "🔄 Starting continuous monitoring (press Ctrl+C to stop)"
        
        while true; do
            run_health_checks
            
            if [[ "$JSON_OUTPUT" == "false" ]]; then
                echo
                log "INFO" "Waiting 60 seconds before next check..."
                echo
            fi
            
            sleep 60
        done
    else
        run_health_checks
    fi
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}[INFO]${NC} Health monitoring stopped"; exit 0' INT

# Run main function
main "$@"