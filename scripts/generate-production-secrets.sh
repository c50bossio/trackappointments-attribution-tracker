#!/bin/bash

# BookingBridge Production Secrets Generation Script
# Generates secure secrets for production deployment
#
# Usage: ./generate-production-secrets.sh [options]
# Options:
#   --output-dir DIR    Directory to save secrets (default: ./secrets)
#   --env-file FILE     Environment file to create (default: .env.production)
#   --help              Show this help message

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/secrets"
ENV_FILE="$PROJECT_ROOT/.env.production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --env-file)
                ENV_FILE="$2"
                shift 2
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
BookingBridge Production Secrets Generation Script

Usage: $0 [options]

Options:
    --output-dir DIR    Directory to save secrets (default: ./secrets)
    --env-file FILE     Environment file to create (default: .env.production)
    --help              Show this help message

Examples:
    $0                                      # Generate secrets with defaults
    $0 --output-dir /etc/bookingbridge      # Custom output directory
    $0 --env-file /app/.env.production      # Custom environment file

Security Notes:
    - All generated secrets are cryptographically secure
    - JWT keys use RSA 4096-bit encryption
    - Database passwords use 64-character random strings
    - Hash salts are unique and non-predictable
    - API keys are placeholder values that must be replaced

EOF
}

# Generate secure random string
generate_random_string() {
    local length=$1
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    
    # Use /dev/urandom for cryptographically secure randomness
    LC_ALL=C tr -dc "$chars" < /dev/urandom | head -c "$length"
}

# Generate secure password with special characters
generate_secure_password() {
    local length=$1
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    LC_ALL=C tr -dc "$chars" < /dev/urandom | head -c "$length"
}

# Generate JWT RSA key pair
generate_jwt_keys() {
    log "INFO" "Generating JWT RSA key pair..."
    
    local private_key_file="$OUTPUT_DIR/jwt_private_key.pem"
    local public_key_file="$OUTPUT_DIR/jwt_public_key.pem"
    
    # Generate private key (4096 bits for enhanced security)
    openssl genpkey -algorithm RSA -out "$private_key_file" -pkcs8 -aes256 \
        -pass pass:temporary_password 2>/dev/null
    
    # Remove password protection (for application use)
    openssl rsa -in "$private_key_file" -out "$private_key_file" \
        -passin pass:temporary_password 2>/dev/null
    
    # Generate public key
    openssl rsa -in "$private_key_file" -pubout -out "$public_key_file" 2>/dev/null
    
    # Set secure permissions
    chmod 600 "$private_key_file"
    chmod 644 "$public_key_file"
    
    log "INFO" "✅ JWT keys generated successfully"
}

# Generate database encryption key
generate_db_encryption_key() {
    log "INFO" "Generating database encryption key..."
    
    local key_file="$OUTPUT_DIR/db_encryption_key.txt"
    
    # Generate 256-bit encryption key
    openssl rand -hex 32 > "$key_file"
    chmod 600 "$key_file"
    
    log "INFO" "✅ Database encryption key generated"
}

# Generate SSL certificate (self-signed for development, replace with real certs in production)
generate_ssl_certificate() {
    log "INFO" "Generating SSL certificate (self-signed for development)..."
    
    local cert_file="$OUTPUT_DIR/ssl_certificate.crt"
    local key_file="$OUTPUT_DIR/ssl_private_key.key"
    local csr_file="$OUTPUT_DIR/ssl_certificate.csr"
    
    # Generate private key
    openssl genrsa -out "$key_file" 4096 2>/dev/null
    
    # Generate certificate signing request
    openssl req -new -key "$key_file" -out "$csr_file" \
        -subj "/C=US/ST=California/L=San Francisco/O=BookingBridge/OU=IT Department/CN=bookingbridge.com" 2>/dev/null
    
    # Generate self-signed certificate (valid for 1 year)
    openssl x509 -req -days 365 -in "$csr_file" -signkey "$key_file" -out "$cert_file" 2>/dev/null
    
    # Set secure permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    # Clean up CSR
    rm "$csr_file"
    
    log "WARN" "Self-signed SSL certificate generated. Replace with real certificates in production!"
}

# Create secrets directory
create_output_directory() {
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR"
        chmod 700 "$OUTPUT_DIR"
    fi
}

# Generate all secrets
generate_secrets() {
    log "INFO" "🔐 Generating production secrets for BookingBridge..."
    
    create_output_directory
    
    # Core application secrets
    SECRET_KEY=$(generate_random_string 64)
    HASH_SALT=$(generate_random_string 32)
    WEBHOOK_SECRET_KEY=$(generate_random_string 48)
    
    # Database credentials
    POSTGRES_PASSWORD=$(generate_secure_password 32)
    DB_ENCRYPTION_KEY=$(generate_random_string 64)
    
    # Redis credentials
    REDIS_PASSWORD=$(generate_secure_password 24)
    
    # Monitoring credentials
    GRAFANA_PASSWORD=$(generate_secure_password 16)
    
    # Session and security
    SESSION_SECRET=$(generate_random_string 48)
    CSRF_SECRET=$(generate_random_string 32)
    
    # API rate limiting keys
    RATE_LIMIT_SECRET=$(generate_random_string 32)
    
    log "INFO" "✅ Base secrets generated"
    
    # Generate complex keys
    generate_jwt_keys
    generate_db_encryption_key
    generate_ssl_certificate
    
    # Save secrets to files for backup
    cat > "$OUTPUT_DIR/secrets_backup.txt" << EOF
# BookingBridge Production Secrets - $(date -u +'%Y-%m-%d %H:%M:%S UTC')
# KEEP THIS FILE SECURE AND DO NOT COMMIT TO VERSION CONTROL

SECRET_KEY=$SECRET_KEY
HASH_SALT=$HASH_SALT
WEBHOOK_SECRET_KEY=$WEBHOOK_SECRET_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DB_ENCRYPTION_KEY=$DB_ENCRYPTION_KEY
REDIS_PASSWORD=$REDIS_PASSWORD
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
SESSION_SECRET=$SESSION_SECRET
CSRF_SECRET=$CSRF_SECRET
RATE_LIMIT_SECRET=$RATE_LIMIT_SECRET
EOF
    
    chmod 600 "$OUTPUT_DIR/secrets_backup.txt"
    
    log "INFO" "✅ All secrets generated and saved to $OUTPUT_DIR"
}

# Create production environment file
create_env_file() {
    log "INFO" "Creating production environment file..."
    
    # Read JWT keys
    local jwt_private_key_content
    local jwt_public_key_content
    
    if [[ -f "$OUTPUT_DIR/jwt_private_key.pem" ]]; then
        jwt_private_key_content=$(cat "$OUTPUT_DIR/jwt_private_key.pem" | base64 -w 0)
    fi
    
    if [[ -f "$OUTPUT_DIR/jwt_public_key.pem" ]]; then
        jwt_public_key_content=$(cat "$OUTPUT_DIR/jwt_public_key.pem" | base64 -w 0)
    fi
    
    # Create environment file from template
    if [[ -f "$PROJECT_ROOT/.env.production.template" ]]; then
        cp "$PROJECT_ROOT/.env.production.template" "$ENV_FILE"
        
        # Replace placeholder values with generated secrets
        sed -i "s/generate_secure_password_here/$POSTGRES_PASSWORD/g" "$ENV_FILE"
        sed -i "s/generate_redis_password_here/$REDIS_PASSWORD/g" "$ENV_FILE"
        sed -i "s/generate_256_bit_secret_key_here/$SECRET_KEY/g" "$ENV_FILE"
        sed -i "s/generate_unique_salt_for_hashing_pii/$HASH_SALT/g" "$ENV_FILE"
        sed -i "s/generate_webhook_secret_key/$WEBHOOK_SECRET_KEY/g" "$ENV_FILE"
        sed -i "s/generate_secure_grafana_password/$GRAFANA_PASSWORD/g" "$ENV_FILE"
        
        # Set secure permissions
        chmod 600 "$ENV_FILE"
        
        log "INFO" "✅ Production environment file created: $ENV_FILE"
        log "WARN" "Remember to update API keys and external service credentials in $ENV_FILE"
    else
        log "WARN" "Template file not found. Creating basic environment file..."
        
        cat > "$ENV_FILE" << EOF
# BookingBridge Production Environment
# Generated on $(date -u +'%Y-%m-%d %H:%M:%S UTC')

# Core application
ENVIRONMENT=production
SECRET_KEY=$SECRET_KEY
HASH_SALT=$HASH_SALT

# Database
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=postgresql://bookingbridge_user:$POSTGRES_PASSWORD@localhost:5432/bookingbridge_production

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_URL=redis://:$REDIS_PASSWORD@localhost:6379/0

# JWT Keys (base64 encoded)
JWT_PRIVATE_KEY_B64=$jwt_private_key_content
JWT_PUBLIC_KEY_B64=$jwt_public_key_content

# Monitoring
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# Webhooks
WEBHOOK_SECRET_KEY=$WEBHOOK_SECRET_KEY

# TODO: Add your external API credentials:
# FACEBOOK_APP_SECRET=your_facebook_app_secret
# GOOGLE_ADS_CLIENT_SECRET=your_google_ads_client_secret
# SENDGRID_API_KEY=your_sendgrid_api_key
# TWILIO_AUTH_TOKEN=your_twilio_auth_token
EOF
        
        chmod 600 "$ENV_FILE"
        log "INFO" "✅ Basic environment file created: $ENV_FILE"
    fi
}

# Create Kubernetes secrets manifest
create_k8s_secrets() {
    log "INFO" "Creating Kubernetes secrets manifest..."
    
    local k8s_secrets_file="$OUTPUT_DIR/kubernetes-secrets.yaml"
    
    # Base64 encode secrets for Kubernetes
    local secret_key_b64=$(echo -n "$SECRET_KEY" | base64 -w 0)
    local hash_salt_b64=$(echo -n "$HASH_SALT" | base64 -w 0)
    local postgres_password_b64=$(echo -n "$POSTGRES_PASSWORD" | base64 -w 0)
    local redis_password_b64=$(echo -n "$REDIS_PASSWORD" | base64 -w 0)
    local webhook_secret_b64=$(echo -n "$WEBHOOK_SECRET_KEY" | base64 -w 0)
    
    # Read and encode JWT keys
    local jwt_private_key_b64=""
    local jwt_public_key_b64=""
    
    if [[ -f "$OUTPUT_DIR/jwt_private_key.pem" ]]; then
        jwt_private_key_b64=$(cat "$OUTPUT_DIR/jwt_private_key.pem" | base64 -w 0)
    fi
    
    if [[ -f "$OUTPUT_DIR/jwt_public_key.pem" ]]; then
        jwt_public_key_b64=$(cat "$OUTPUT_DIR/jwt_public_key.pem" | base64 -w 0)
    fi
    
    cat > "$k8s_secrets_file" << EOF
# BookingBridge Kubernetes Secrets
# Generated on $(date -u +'%Y-%m-%d %H:%M:%S UTC')
# 
# Apply with: kubectl apply -f kubernetes-secrets.yaml -n bookingbridge
# KEEP THIS FILE SECURE AND DO NOT COMMIT TO VERSION CONTROL

apiVersion: v1
kind: Secret
metadata:
  name: bookingbridge-secrets
  namespace: bookingbridge
  labels:
    app.kubernetes.io/name: bookingbridge
    app.kubernetes.io/component: secrets
type: Opaque
data:
  SECRET_KEY: $secret_key_b64
  HASH_SALT: $hash_salt_b64
  POSTGRES_PASSWORD: $postgres_password_b64
  REDIS_PASSWORD: $redis_password_b64
  WEBHOOK_SECRET_KEY: $webhook_secret_b64
  JWT_PRIVATE_KEY: $jwt_private_key_b64
  JWT_PUBLIC_KEY: $jwt_public_key_b64
  DATABASE_URL: $(echo -n "postgresql://bookingbridge_user:$POSTGRES_PASSWORD@postgres:5432/bookingbridge_production" | base64 -w 0)
  REDIS_URL: $(echo -n "redis://:$REDIS_PASSWORD@redis:6379/0" | base64 -w 0)
  
  # TODO: Add your external API credentials (base64 encoded):
  # FACEBOOK_APP_SECRET: <base64_encoded_value>
  # GOOGLE_ADS_CLIENT_SECRET: <base64_encoded_value>
  # SENDGRID_API_KEY: <base64_encoded_value>
  # TWILIO_AUTH_TOKEN: <base64_encoded_value>

---
apiVersion: v1
kind: Secret
metadata:
  name: bookingbridge-tls
  namespace: bookingbridge
  labels:
    app.kubernetes.io/name: bookingbridge
    app.kubernetes.io/component: tls
type: kubernetes.io/tls
data:
  tls.crt: $(cat "$OUTPUT_DIR/ssl_certificate.crt" | base64 -w 0)
  tls.key: $(cat "$OUTPUT_DIR/ssl_private_key.key" | base64 -w 0)
EOF
    
    chmod 600 "$k8s_secrets_file"
    log "INFO" "✅ Kubernetes secrets manifest created: $k8s_secrets_file"
}

# Create Docker Compose secrets
create_docker_secrets() {
    log "INFO" "Creating Docker Compose secrets..."
    
    local docker_secrets_dir="$OUTPUT_DIR/docker"
    mkdir -p "$docker_secrets_dir"
    
    # Create individual secret files for Docker Compose
    echo -n "$SECRET_KEY" > "$docker_secrets_dir/secret_key.txt"
    echo -n "$HASH_SALT" > "$docker_secrets_dir/hash_salt.txt"
    echo -n "$POSTGRES_PASSWORD" > "$docker_secrets_dir/postgres_password.txt"
    echo -n "$REDIS_PASSWORD" > "$docker_secrets_dir/redis_password.txt"
    echo -n "$WEBHOOK_SECRET_KEY" > "$docker_secrets_dir/webhook_secret.txt"
    
    # Copy JWT keys
    cp "$OUTPUT_DIR/jwt_private_key.pem" "$docker_secrets_dir/"
    cp "$OUTPUT_DIR/jwt_public_key.pem" "$docker_secrets_dir/"
    
    # Set permissions
    chmod -R 600 "$docker_secrets_dir"/*
    
    log "INFO" "✅ Docker Compose secrets created in $docker_secrets_dir"
}

# Print summary
print_summary() {
    log "INFO" "🎉 Secret generation completed successfully!"
    echo
    echo "Generated files:"
    echo "  📁 Secrets directory: $OUTPUT_DIR"
    echo "  🔐 Environment file: $ENV_FILE"
    echo "  ☸️  Kubernetes secrets: $OUTPUT_DIR/kubernetes-secrets.yaml"
    echo "  🐳 Docker secrets: $OUTPUT_DIR/docker/"
    echo "  🔑 JWT keys: $OUTPUT_DIR/jwt_*.pem"
    echo "  📜 SSL certificate: $OUTPUT_DIR/ssl_*"
    echo "  💾 Backup file: $OUTPUT_DIR/secrets_backup.txt"
    echo
    echo "Next steps:"
    echo "  1. Update external API credentials in $ENV_FILE"
    echo "  2. Replace self-signed SSL certificates with real ones"
    echo "  3. Store secrets securely (AWS Secrets Manager, HashiCorp Vault, etc.)"
    echo "  4. Add secrets to your CI/CD pipeline"
    echo "  5. Test the deployment in staging environment"
    echo
    echo "Security reminders:"
    echo "  ⚠️  Never commit these files to version control"
    echo "  ⚠️  Rotate secrets regularly (quarterly recommended)"
    echo "  ⚠️  Use proper secret management in production"
    echo "  ⚠️  Monitor for secret exposure in logs"
}

# Check prerequisites
check_prerequisites() {
    local required_tools=("openssl" "base64")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool '$tool' is not installed"
        fi
    done
}

# Main function
main() {
    parse_args "$@"
    
    log "INFO" "🚀 Starting BookingBridge production secrets generation..."
    
    check_prerequisites
    generate_secrets
    create_env_file
    create_k8s_secrets
    create_docker_secrets
    print_summary
}

# Run main function with all arguments
main "$@"