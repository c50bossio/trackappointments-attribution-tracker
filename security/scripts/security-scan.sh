#!/bin/bash

# BookingBridge Security Scanning Script
# Performs comprehensive security checks on the application

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCAN_DIR="${1:-/app}"
OUTPUT_DIR="${2:-/tmp/security-scan}"
SEVERITY_THRESHOLD="${3:-MEDIUM}"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_info "Starting security scan of BookingBridge application"
print_info "Scan directory: $SCAN_DIR"
print_info "Output directory: $OUTPUT_DIR"
print_info "Severity threshold: $SEVERITY_THRESHOLD"

# 1. Dependency vulnerability scanning
print_info "Running dependency vulnerability scan..."

# Python dependencies
if [ -f "$SCAN_DIR/backend/requirements.txt" ]; then
    print_info "Scanning Python dependencies..."
    safety check -r "$SCAN_DIR/backend/requirements.txt" --json > "$OUTPUT_DIR/python-vulnerabilities.json" || true
    
    # Parse results
    if [ -s "$OUTPUT_DIR/python-vulnerabilities.json" ]; then
        vulnerabilities=$(jq length "$OUTPUT_DIR/python-vulnerabilities.json")
        if [ "$vulnerabilities" -gt 0 ]; then
            print_warning "Found $vulnerabilities Python dependency vulnerabilities"
            jq -r '.[] | "- \(.package_name) \(.installed_version): \(.vulnerability_id)"' "$OUTPUT_DIR/python-vulnerabilities.json"
        else
            print_success "No Python dependency vulnerabilities found"
        fi
    fi
fi

# Node.js dependencies
if [ -f "$SCAN_DIR/frontend/package.json" ]; then
    print_info "Scanning Node.js dependencies..."
    cd "$SCAN_DIR/frontend"
    npm audit --json > "$OUTPUT_DIR/npm-vulnerabilities.json" || true
    
    # Parse results
    if [ -s "$OUTPUT_DIR/npm-vulnerabilities.json" ]; then
        high_vulns=$(jq -r '.metadata.vulnerabilities.high // 0' "$OUTPUT_DIR/npm-vulnerabilities.json")
        critical_vulns=$(jq -r '.metadata.vulnerabilities.critical // 0' "$OUTPUT_DIR/npm-vulnerabilities.json")
        
        if [ "$critical_vulns" -gt 0 ] || [ "$high_vulns" -gt 0 ]; then
            print_warning "Found $critical_vulns critical and $high_vulns high severity Node.js vulnerabilities"
        else
            print_success "No critical or high severity Node.js vulnerabilities found"
        fi
    fi
    cd - > /dev/null
fi

# 2. Static Application Security Testing (SAST)
print_info "Running static application security testing..."

# Bandit for Python
if command -v bandit &> /dev/null && [ -d "$SCAN_DIR/backend" ]; then
    print_info "Running Bandit security scan on Python code..."
    bandit -r "$SCAN_DIR/backend" -f json -o "$OUTPUT_DIR/bandit-results.json" -x "*/tests/*,*/venv/*" || true
    
    if [ -s "$OUTPUT_DIR/bandit-results.json" ]; then
        high_issues=$(jq '[.results[] | select(.issue_severity == "HIGH")] | length' "$OUTPUT_DIR/bandit-results.json")
        medium_issues=$(jq '[.results[] | select(.issue_severity == "MEDIUM")] | length' "$OUTPUT_DIR/bandit-results.json")
        
        if [ "$high_issues" -gt 0 ]; then
            print_warning "Found $high_issues high severity security issues in Python code"
            jq -r '.results[] | select(.issue_severity == "HIGH") | "- \(.filename):\(.line_number) - \(.test_name): \(.issue_text)"' "$OUTPUT_DIR/bandit-results.json"
        fi
        
        if [ "$medium_issues" -gt 0 ]; then
            print_info "Found $medium_issues medium severity security issues in Python code"
        fi
        
        if [ "$high_issues" -eq 0 ] && [ "$medium_issues" -eq 0 ]; then
            print_success "No significant security issues found in Python code"
        fi
    fi
fi

# Semgrep for comprehensive SAST
if command -v semgrep &> /dev/null; then
    print_info "Running Semgrep security analysis..."
    semgrep --config=auto --json --output="$OUTPUT_DIR/semgrep-results.json" "$SCAN_DIR" || true
    
    if [ -s "$OUTPUT_DIR/semgrep-results.json" ]; then
        total_findings=$(jq '.results | length' "$OUTPUT_DIR/semgrep-results.json")
        error_findings=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$OUTPUT_DIR/semgrep-results.json")
        warning_findings=$(jq '[.results[] | select(.extra.severity == "WARNING")] | length' "$OUTPUT_DIR/semgrep-results.json")
        
        print_info "Semgrep found $total_findings total findings ($error_findings errors, $warning_findings warnings)"
        
        if [ "$error_findings" -gt 0 ]; then
            print_warning "Critical security issues found:"
            jq -r '.results[] | select(.extra.severity == "ERROR") | "- \(.path):\(.start.line) - \(.extra.message)"' "$OUTPUT_DIR/semgrep-results.json" | head -10
        fi
    fi
fi

# 3. Container security scanning
print_info "Running container security scan..."

# Trivy container scanning
if command -v trivy &> /dev/null; then
    print_info "Scanning container images with Trivy..."
    
    # Scan backend image
    if docker images | grep -q "bookingbridge.*backend"; then
        backend_image=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "bookingbridge.*backend" | head -1)
        print_info "Scanning backend image: $backend_image"
        trivy image --format json --output "$OUTPUT_DIR/trivy-backend.json" "$backend_image" || true
        
        if [ -s "$OUTPUT_DIR/trivy-backend.json" ]; then
            critical_vulns=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$OUTPUT_DIR/trivy-backend.json")
            high_vulns=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$OUTPUT_DIR/trivy-backend.json")
            
            print_info "Backend image: $critical_vulns critical, $high_vulns high vulnerabilities"
        fi
    fi
    
    # Scan frontend image
    if docker images | grep -q "bookingbridge.*frontend"; then
        frontend_image=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "bookingbridge.*frontend" | head -1)
        print_info "Scanning frontend image: $frontend_image"
        trivy image --format json --output "$OUTPUT_DIR/trivy-frontend.json" "$frontend_image" || true
        
        if [ -s "$OUTPUT_DIR/trivy-frontend.json" ]; then
            critical_vulns=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$OUTPUT_DIR/trivy-frontend.json")
            high_vulns=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$OUTPUT_DIR/trivy-frontend.json")
            
            print_info "Frontend image: $critical_vulns critical, $high_vulns high vulnerabilities"
        fi
    fi
fi

# 4. Configuration security scanning
print_info "Scanning configuration files..."

# Check for hardcoded secrets
print_info "Checking for hardcoded secrets..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect --source "$SCAN_DIR" --report-format json --report-path "$OUTPUT_DIR/gitleaks-results.json" || true
    
    if [ -s "$OUTPUT_DIR/gitleaks-results.json" ]; then
        secrets_found=$(jq length "$OUTPUT_DIR/gitleaks-results.json")
        if [ "$secrets_found" -gt 0 ]; then
            print_warning "Found $secrets_found potential secrets in code"
            jq -r '.[] | "- \(.File):\(.StartLine) - \(.Description)"' "$OUTPUT_DIR/gitleaks-results.json" | head -5
        else
            print_success "No hardcoded secrets detected"
        fi
    fi
else
    # Fallback regex-based secret detection
    print_info "Using regex-based secret detection..."
    secret_patterns=(
        "password\s*=\s*['\"].*['\"]"
        "api_key\s*=\s*['\"].*['\"]"
        "secret\s*=\s*['\"].*['\"]"
        "token\s*=\s*['\"].*['\"]"
        "AKIA[0-9A-Z]{16}"  # AWS Access Key
        "AIza[0-9A-Za-z\\-_]{35}"  # Google API Key
    )
    
    secrets_found=0
    for pattern in "${secret_patterns[@]}"; do
        matches=$(find "$SCAN_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) -exec grep -l -i -E "$pattern" {} \; 2>/dev/null | grep -v "test" | head -5)
        if [ -n "$matches" ]; then
            secrets_found=$((secrets_found + 1))
            echo "$matches" | while read -r file; do
                print_warning "Potential secret in: $file"
            done
        fi
    done
    
    if [ "$secrets_found" -eq 0 ]; then
        print_success "No obvious hardcoded secrets found"
    fi
fi

# Check Docker security
print_info "Checking Docker configuration security..."
if [ -f "$SCAN_DIR/Dockerfile" ] || [ -f "$SCAN_DIR/backend/Dockerfile.production" ]; then
    dockerfile_issues=0
    
    for dockerfile in $(find "$SCAN_DIR" -name "Dockerfile*"); do
        print_info "Checking $dockerfile..."
        
        # Check for running as root
        if ! grep -q "USER " "$dockerfile"; then
            print_warning "$dockerfile: Container may run as root"
            dockerfile_issues=$((dockerfile_issues + 1))
        fi
        
        # Check for COPY with excessive permissions
        if grep -q "COPY.*--chmod=777" "$dockerfile"; then
            print_warning "$dockerfile: Excessive permissions in COPY command"
            dockerfile_issues=$((dockerfile_issues + 1))
        fi
        
        # Check for hardcoded secrets
        if grep -q -E "(PASSWORD|SECRET|KEY)=" "$dockerfile"; then
            print_warning "$dockerfile: Potential hardcoded secrets"
            dockerfile_issues=$((dockerfile_issues + 1))
        fi
    done
    
    if [ "$dockerfile_issues" -eq 0 ]; then
        print_success "No major Docker security issues found"
    fi
fi

# 5. Network security checks
print_info "Checking network security configuration..."

# Check for exposed services
if command -v nmap &> /dev/null; then
    print_info "Scanning for exposed services on localhost..."
    nmap -sT -O localhost 2>/dev/null | grep "open" > "$OUTPUT_DIR/open-ports.txt" || true
    
    if [ -s "$OUTPUT_DIR/open-ports.txt" ]; then
        open_ports=$(wc -l < "$OUTPUT_DIR/open-ports.txt")
        print_info "Found $open_ports open ports"
        head -5 "$OUTPUT_DIR/open-ports.txt"
    fi
fi

# 6. Generate security report
print_info "Generating security report..."

cat > "$OUTPUT_DIR/security-report.md" << EOF
# BookingBridge Security Scan Report

**Scan Date:** $(date -u)
**Scan Directory:** $SCAN_DIR
**Severity Threshold:** $SEVERITY_THRESHOLD

## Summary

### Dependency Vulnerabilities
- Python: $([ -f "$OUTPUT_DIR/python-vulnerabilities.json" ] && jq length "$OUTPUT_DIR/python-vulnerabilities.json" || echo "N/A")
- Node.js: $([ -f "$OUTPUT_DIR/npm-vulnerabilities.json" ] && jq -r '.metadata.vulnerabilities.critical // 0' "$OUTPUT_DIR/npm-vulnerabilities.json" || echo "N/A") critical, $([ -f "$OUTPUT_DIR/npm-vulnerabilities.json" ] && jq -r '.metadata.vulnerabilities.high // 0' "$OUTPUT_DIR/npm-vulnerabilities.json" || echo "N/A") high

### Code Security Issues
- Bandit (Python): $([ -f "$OUTPUT_DIR/bandit-results.json" ] && jq '[.results[] | select(.issue_severity == "HIGH")] | length' "$OUTPUT_DIR/bandit-results.json" || echo "N/A") high severity
- Semgrep: $([ -f "$OUTPUT_DIR/semgrep-results.json" ] && jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$OUTPUT_DIR/semgrep-results.json" || echo "N/A") errors

### Container Security
- Backend Image: $([ -f "$OUTPUT_DIR/trivy-backend.json" ] && jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$OUTPUT_DIR/trivy-backend.json" || echo "N/A") critical vulnerabilities
- Frontend Image: $([ -f "$OUTPUT_DIR/trivy-frontend.json" ] && jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$OUTPUT_DIR/trivy-frontend.json" || echo "N/A") critical vulnerabilities

### Secrets Detection
- Potential secrets found: $([ -f "$OUTPUT_DIR/gitleaks-results.json" ] && jq length "$OUTPUT_DIR/gitleaks-results.json" || echo "Manual check performed")

## Recommendations

1. **Update Dependencies:** Address all critical and high-severity vulnerabilities
2. **Fix Code Issues:** Review and fix high-severity static analysis findings
3. **Container Security:** Update base images and fix container vulnerabilities
4. **Secrets Management:** Ensure no hardcoded secrets in code
5. **Network Security:** Review open ports and exposed services

## Detailed Results

Detailed scan results are available in the following files:
- Python vulnerabilities: python-vulnerabilities.json
- Node.js vulnerabilities: npm-vulnerabilities.json
- Static analysis (Bandit): bandit-results.json
- Static analysis (Semgrep): semgrep-results.json
- Container scan (Backend): trivy-backend.json
- Container scan (Frontend): trivy-frontend.json
- Secrets detection: gitleaks-results.json

EOF

print_success "Security scan completed!"
print_info "Report generated: $OUTPUT_DIR/security-report.md"

# Set exit code based on findings
critical_issues=0

# Check for critical vulnerabilities
if [ -f "$OUTPUT_DIR/python-vulnerabilities.json" ] && [ "$(jq length "$OUTPUT_DIR/python-vulnerabilities.json")" -gt 0 ]; then
    critical_issues=$((critical_issues + 1))
fi

if [ -f "$OUTPUT_DIR/npm-vulnerabilities.json" ] && [ "$(jq -r '.metadata.vulnerabilities.critical // 0' "$OUTPUT_DIR/npm-vulnerabilities.json")" -gt 0 ]; then
    critical_issues=$((critical_issues + 1))
fi

if [ -f "$OUTPUT_DIR/bandit-results.json" ] && [ "$(jq '[.results[] | select(.issue_severity == "HIGH")] | length' "$OUTPUT_DIR/bandit-results.json")" -gt 0 ]; then
    critical_issues=$((critical_issues + 1))
fi

if [ "$critical_issues" -gt 0 ]; then
    print_error "Security scan found critical issues that need immediate attention!"
    exit 1
else
    print_success "Security scan completed without critical issues"
    exit 0
fi