#!/bin/bash

# BookingBridge Secrets Generation Script
# Generates secure secrets for production deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if required tools are installed
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if ! command -v base64 &> /dev/null; then
        missing_deps+=("base64")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Generate a random secret key
generate_secret_key() {
    python3 -c "import secrets; print(secrets.token_urlsafe(64))"
}

# Generate a random salt
generate_salt() {
    python3 -c "import secrets; print(secrets.token_urlsafe(32))"
}

# Generate RSA key pair for JWT
generate_jwt_keys() {
    local key_dir="$1"
    
    print_info "Generating RSA key pair for JWT..."
    
    # Create keys directory if it doesn't exist
    mkdir -p "$key_dir"
    
    # Generate private key
    openssl genrsa -out "$key_dir/jwt_private_key.pem" 4096
    
    # Generate public key
    openssl rsa -in "$key_dir/jwt_private_key.pem" -pubout -out "$key_dir/jwt_public_key.pem"
    
    # Set proper permissions
    chmod 600 "$key_dir/jwt_private_key.pem"
    chmod 644 "$key_dir/jwt_public_key.pem"
    
    print_success "RSA key pair generated in $key_dir"
}

# Generate database passwords
generate_database_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Generate TLS certificates (self-signed for development)
generate_tls_certificates() {
    local cert_dir="$1"
    local domain="${2:-bookingbridge.com}"
    
    print_info "Generating self-signed TLS certificates for $domain..."
    
    mkdir -p "$cert_dir"
    
    # Generate private key
    openssl genrsa -out "$cert_dir/tls.key" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$cert_dir/tls.key" -out "$cert_dir/tls.csr" -subj "/C=US/ST=CA/L=San Francisco/O=BookingBridge/CN=$domain"
    
    # Generate self-signed certificate
    openssl x509 -req -in "$cert_dir/tls.csr" -signkey "$cert_dir/tls.key" -out "$cert_dir/tls.crt" -days 365
    
    # Clean up CSR
    rm "$cert_dir/tls.csr"
    
    # Set proper permissions
    chmod 600 "$cert_dir/tls.key"
    chmod 644 "$cert_dir/tls.crt"
    
    print_success "TLS certificates generated in $cert_dir"
    print_warning "These are self-signed certificates. Use proper CA-signed certificates in production."
}

# Generate Kubernetes secrets YAML
generate_k8s_secrets() {
    local secrets_file="$1"
    local environment="${2:-production}"
    
    print_info "Generating Kubernetes secrets for $environment environment..."
    
    # Generate secrets
    local secret_key=$(generate_secret_key)
    local hash_salt=$(generate_salt)
    local encryption_key=$(generate_salt)
    local postgres_password=$(generate_database_password)
    local redis_password=$(generate_database_password)
    
    # Read JWT keys
    local jwt_private_key=""
    local jwt_public_key=""
    
    if [ -f "keys/jwt_private_key.pem" ]; then
        jwt_private_key=$(cat keys/jwt_private_key.pem | base64 -w 0)
        jwt_public_key=$(cat keys/jwt_public_key.pem | base64 -w 0)
    else
        print_warning "JWT keys not found. Please generate them first with: $0 --jwt-keys"
    fi
    
    # Generate secrets YAML
    cat > "$secrets_file" << EOF
# Generated Kubernetes Secrets for BookingBridge $environment
# Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

apiVersion: v1
kind: Secret
metadata:
  name: bookingbridge-secrets
  namespace: bookingbridge
  labels:
    app.kubernetes.io/name: bookingbridge
    app.kubernetes.io/component: secrets
    environment: $environment
type: Opaque
data:
  # Application Secrets
  SECRET_KEY: $(echo -n "$secret_key" | base64 -w 0)
  HASH_SALT: $(echo -n "$hash_salt" | base64 -w 0)
  ENCRYPTION_KEY: $(echo -n "$encryption_key" | base64 -w 0)
  
  # Database Credentials
  DATABASE_URL: $(echo -n "postgresql://bookingbridge:${postgres_password}@bookingbridge-postgresql:5432/bookingbridge" | base64 -w 0)
  POSTGRES_USER: $(echo -n "bookingbridge" | base64 -w 0)
  POSTGRES_PASSWORD: $(echo -n "$postgres_password" | base64 -w 0)
  POSTGRES_DB: $(echo -n "bookingbridge" | base64 -w 0)
  
  # Redis Credentials
  REDIS_URL: $(echo -n "redis://:${redis_password}@bookingbridge-redis:6379/0" | base64 -w 0)
  REDIS_PASSWORD: $(echo -n "$redis_password" | base64 -w 0)
  
  # JWT Keys
  JWT_PRIVATE_KEY: $jwt_private_key
  JWT_PUBLIC_KEY: $jwt_public_key
  
  # Placeholder API Keys (REPLACE WITH ACTUAL VALUES)
  FACEBOOK_APP_SECRET: $(echo -n "REPLACE_WITH_ACTUAL_FACEBOOK_APP_SECRET" | base64 -w 0)
  GOOGLE_ADS_CLIENT_SECRET: $(echo -n "REPLACE_WITH_ACTUAL_GOOGLE_ADS_CLIENT_SECRET" | base64 -w 0)
  SENDGRID_API_KEY: $(echo -n "REPLACE_WITH_ACTUAL_SENDGRID_API_KEY" | base64 -w 0)
  TWILIO_AUTH_TOKEN: $(echo -n "REPLACE_WITH_ACTUAL_TWILIO_AUTH_TOKEN" | base64 -w 0)
  SENTRY_DSN: $(echo -n "REPLACE_WITH_ACTUAL_SENTRY_DSN" | base64 -w 0)

---
# TLS Certificate Secret
apiVersion: v1
kind: Secret
metadata:
  name: bookingbridge-tls
  namespace: bookingbridge
  labels:
    app.kubernetes.io/name: bookingbridge
    app.kubernetes.io/component: tls
    environment: $environment
type: kubernetes.io/tls
data:
  tls.crt: $(if [ -f "ssl/tls.crt" ]; then base64 -w 0 < ssl/tls.crt; else echo "REPLACE_WITH_BASE64_ENCODED_CERTIFICATE"; fi)
  tls.key: $(if [ -f "ssl/tls.key" ]; then base64 -w 0 < ssl/tls.key; else echo "REPLACE_WITH_BASE64_ENCODED_PRIVATE_KEY"; fi)

EOF
    
    print_success "Kubernetes secrets generated in $secrets_file"
    print_warning "Remember to replace placeholder API keys with actual values!"
}

# Generate .env file with secrets
generate_env_file() {
    local env_file="$1"
    local environment="${2:-production}"
    
    print_info "Generating .env file for $environment environment..."
    
    # Copy template
    if [ -f ".env.${environment}.template" ]; then
        cp ".env.${environment}.template" "$env_file"
    else
        print_error "Template file .env.${environment}.template not found"
        return 1
    fi
    
    # Generate secrets
    local secret_key=$(generate_secret_key)
    local hash_salt=$(generate_salt)
    local encryption_key=$(generate_salt)
    local postgres_password=$(generate_database_password)
    local redis_password=$(generate_database_password)
    
    # Replace placeholders
    sed -i.bak \
        -e "s/YOUR_SUPER_SECRET_KEY_REPLACE_THIS_IN_PRODUCTION/$secret_key/g" \
        -e "s/YOUR_HASH_SALT_FOR_PII_PROTECTION/$hash_salt/g" \
        -e "s/YOUR_ENCRYPTION_KEY_FOR_SENSITIVE_DATA/$encryption_key/g" \
        -e "s/YOUR_STRONG_DATABASE_PASSWORD/$postgres_password/g" \
        -e "s/YOUR_STRONG_REDIS_PASSWORD/$redis_password/g" \
        -e "s/YOUR_STAGING_SECRET_KEY_DIFFERENT_FROM_PRODUCTION/$secret_key/g" \
        -e "s/YOUR_STAGING_HASH_SALT_DIFFERENT_FROM_PRODUCTION/$hash_salt/g" \
        -e "s/YOUR_STAGING_ENCRYPTION_KEY_DIFFERENT_FROM_PRODUCTION/$encryption_key/g" \
        -e "s/YOUR_STAGING_DATABASE_PASSWORD/$postgres_password/g" \
        -e "s/YOUR_STAGING_REDIS_PASSWORD/$redis_password/g" \
        "$env_file"
    
    # Remove backup file
    rm "${env_file}.bak"
    
    print_success "Environment file generated: $env_file"
    print_warning "Please review and update API keys and external service credentials!"
}

# Create secrets summary
create_secrets_summary() {
    local summary_file="secrets-summary.txt"
    
    print_info "Creating secrets summary..."
    
    cat > "$summary_file" << EOF
BookingBridge Secrets Summary
Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

=== IMPORTANT SECURITY NOTES ===
1. Keep all generated secrets secure and never commit them to version control
2. Use different secrets for staging and production environments
3. Rotate secrets regularly (every 90 days recommended)
4. Replace all placeholder API keys with actual values from service providers

=== GENERATED FILES ===
- JWT RSA Keys: keys/jwt_private_key.pem, keys/jwt_public_key.pem
- TLS Certificates: ssl/tls.crt, ssl/tls.key (self-signed, replace in production)
- Kubernetes Secrets: k8s/secrets-generated.yaml
- Environment Files: .env.production, .env.staging

=== NEXT STEPS ===
1. Review all generated files and update placeholder values
2. Store secrets securely (use vault or secure secret management)
3. Apply Kubernetes secrets: kubectl apply -f k8s/secrets-generated.yaml
4. Configure external API keys for:
   - Facebook App Secret
   - Google Ads Client Secret
   - SendGrid API Key
   - Twilio Auth Token
   - Sentry DSN

=== SECURITY CHECKLIST ===
[ ] Secrets are stored securely
[ ] Placeholder values replaced with actual API keys
[ ] Different secrets used for staging vs production
[ ] TLS certificates obtained from trusted CA for production
[ ] Database passwords are strong and unique
[ ] JWT keys are kept secure and not exposed
[ ] Backup and recovery procedures documented

For additional security, consider using:
- HashiCorp Vault for secret management
- AWS Secrets Manager or similar cloud service
- Kubernetes external-secrets operator
EOF
    
    print_success "Secrets summary created: $summary_file"
}

# Main function
main() {
    print_info "BookingBridge Secrets Generation Script"
    print_info "========================================"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --jwt-keys)
                check_dependencies
                generate_jwt_keys "keys"
                exit 0
                ;;
            --tls-certs)
                check_dependencies
                generate_tls_certificates "ssl" "${2:-bookingbridge.com}"
                exit 0
                ;;
            --k8s-secrets)
                check_dependencies
                generate_k8s_secrets "k8s/secrets-generated.yaml" "${2:-production}"
                exit 0
                ;;
            --env-file)
                check_dependencies
                generate_env_file ".env.${2:-production}" "${2:-production}"
                exit 0
                ;;
            --all)
                check_dependencies
                generate_jwt_keys "keys"
                generate_tls_certificates "ssl"
                generate_k8s_secrets "k8s/secrets-generated.yaml" "production"
                generate_env_file ".env.production" "production"
                generate_env_file ".env.staging" "staging"
                create_secrets_summary
                print_success "All secrets generated successfully!"
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --jwt-keys          Generate JWT RSA key pair"
                echo "  --tls-certs [domain] Generate TLS certificates (default: bookingbridge.com)"
                echo "  --k8s-secrets [env] Generate Kubernetes secrets (default: production)"
                echo "  --env-file [env]    Generate .env file (default: production)"
                echo "  --all               Generate all secrets and files"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --all                    # Generate everything"
                echo "  $0 --jwt-keys               # Generate only JWT keys"
                echo "  $0 --tls-certs example.com  # Generate TLS certs for example.com"
                echo "  $0 --k8s-secrets staging    # Generate staging K8s secrets"
                echo "  $0 --env-file staging       # Generate staging .env file"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
    
    # Default behavior - show help
    print_warning "No options specified. Use --help for usage information or --all to generate everything."
    exit 1
}

# Run main function
main "$@"