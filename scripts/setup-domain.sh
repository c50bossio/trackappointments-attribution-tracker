#!/bin/bash
# BookingBridge Domain Setup Script
# Sets up bookingbridge.com domain with Cloudflare

set -e

echo "🌐 BookingBridge Domain Setup"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOMAIN="bookingbridge.com"

echo -e "${BLUE}Setting up domain: ${DOMAIN}${NC}"
echo ""

# Step 1: Check domain availability
echo -e "${YELLOW}Step 1: Domain Availability Check${NC}"
echo "We need to check if ${DOMAIN} is available for purchase."
echo ""
echo "Manual steps (since CLI requires Node.js v20+):"
echo "1. Go to https://www.cloudflare.com/products/registrar/"
echo "2. Search for '${DOMAIN}'"
echo "3. Check availability and pricing"
echo ""
read -p "Is ${DOMAIN} available for purchase? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Domain not available. Please choose an alternative domain.${NC}"
    echo "Suggested alternatives:"
    echo "- bookingbridge.io"
    echo "- bookingbridge.app" 
    echo "- mybookingbridge.com"
    echo "- bookingbridge.dev"
    exit 1
fi

# Step 2: Domain purchase
echo ""
echo -e "${YELLOW}Step 2: Domain Purchase${NC}"
echo "To purchase ${DOMAIN} through Cloudflare:"
echo ""
echo "1. Go to https://dash.cloudflare.com/"
echo "2. Sign in to your Cloudflare account (or create one)"
echo "3. Click 'Register Domain' or go to the Registrar section"
echo "4. Search for '${DOMAIN}'"
echo "5. Complete the purchase process"
echo ""
echo "Cloudflare domain pricing is typically at-cost with no markup:"
echo "- .com domains: ~$9.15/year"
echo "- Includes free WHOIS privacy protection"
echo "- Includes free SSL certificates"
echo ""
read -p "Have you completed the domain purchase? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please complete the domain purchase first, then run this script again.${NC}"
    exit 0
fi

# Step 3: DNS Configuration
echo ""
echo -e "${YELLOW}Step 3: DNS Configuration${NC}"
echo "Setting up DNS records for BookingBridge platform..."
echo ""

# Create DNS configuration file
cat > ../dns-config.txt << EOF
# BookingBridge DNS Configuration for ${DOMAIN}
# Add these records in your Cloudflare DNS dashboard

# Main application (production)
Type: A
Name: @
Value: [YOUR_PRODUCTION_SERVER_IP]
Proxy: Yes (Orange cloud)

# WWW redirect
Type: CNAME
Name: www
Value: ${DOMAIN}
Proxy: Yes (Orange cloud)

# API subdomain
Type: A
Name: api
Value: [YOUR_API_SERVER_IP]
Proxy: Yes (Orange cloud)

# Staging environment
Type: A
Name: staging
Value: [YOUR_STAGING_SERVER_IP]
Proxy: Yes (Orange cloud)

# Admin panel
Type: A
Name: admin
Value: [YOUR_ADMIN_SERVER_IP]
Proxy: Yes (Orange cloud)

# Development
Type: A
Name: dev
Value: [YOUR_DEV_SERVER_IP]
Proxy: No (Gray cloud - for development only)
EOF

echo "DNS configuration saved to: ../dns-config.txt"
echo ""
echo "Manual DNS setup in Cloudflare Dashboard:"
echo "1. Go to https://dash.cloudflare.com/"
echo "2. Select your ${DOMAIN} domain"
echo "3. Go to DNS > Records"
echo "4. Add the records listed in dns-config.txt"
echo ""

# Step 4: SSL and Security
echo -e "${YELLOW}Step 4: SSL and Security Configuration${NC}"
echo "Configuring SSL and security settings..."
echo ""

cat > ../cloudflare-security-config.txt << EOF
# BookingBridge Cloudflare Security Configuration
# Apply these settings in your Cloudflare dashboard

## SSL/TLS Settings
Path: SSL/TLS > Overview
- Encryption Mode: Full (strict)
- Always Use HTTPS: On

## SSL/TLS > Edge Certificates
- Always Use HTTPS: On
- HTTP Strict Transport Security (HSTS): On
- Minimum TLS Version: 1.2
- Opportunistic Encryption: On
- TLS 1.3: On

## Security > WAF
- Web Application Firewall: On
- OWASP Core Ruleset: On
- Cloudflare Managed Rules: On

## Security > Firewall Rules
Add custom rules for API protection:
1. Rate limiting for API endpoints
2. Geographic restrictions if needed
3. Bot protection for booking forms

## Speed > Optimization
- Auto Minify: CSS, HTML, JavaScript
- Brotli Compression: On
- Early Hints: On

## Caching > Configuration
- Browser Cache TTL: 4 hours
- Caching Level: Standard
EOF

echo "Security configuration saved to: ../cloudflare-security-config.txt"
echo ""

# Step 5: Update production configuration
echo -e "${YELLOW}Step 5: Update Production Configuration${NC}"
echo "Updating BookingBridge configuration files..."
echo ""

# Update docker-compose.production.yml
if [ -f "../docker-compose.production.yml" ]; then
    # Create backup
    cp ../docker-compose.production.yml ../docker-compose.production.yml.bak
    
    # Update domain references
    sed -i.tmp "s/localhost:3001/${DOMAIN}/g" ../docker-compose.production.yml
    sed -i.tmp "s/localhost:8001/api.${DOMAIN}/g" ../docker-compose.production.yml
    rm ../docker-compose.production.yml.tmp
    
    echo "✅ Updated docker-compose.production.yml"
fi

# Update frontend configuration
if [ -f "../frontend/next.config.js" ]; then
    # Create backup
    cp ../frontend/next.config.js ../frontend/next.config.js.bak
    
    # Add production domain configuration
    cat >> ../frontend/next.config.js << EOF

// Production domain configuration
const productionConfig = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'https://api.${DOMAIN}/api/:path*'
      }
    ]
  },
  env: {
    NEXT_PUBLIC_API_URL: 'https://api.${DOMAIN}',
    NEXT_PUBLIC_DOMAIN: '${DOMAIN}'
  }
}

module.exports = process.env.NODE_ENV === 'production' ? productionConfig : module.exports
EOF
    
    echo "✅ Updated frontend/next.config.js"
fi

# Update backend CORS configuration
if [ -f "../backend/.env" ]; then
    # Create backup
    cp ../backend/.env ../backend/.env.bak
    
    # Update CORS origins
    sed -i.tmp "s/CORS_ORIGINS=.*/CORS_ORIGINS=https:\/\/${DOMAIN},https:\/\/www.${DOMAIN},https:\/\/api.${DOMAIN}/g" ../backend/.env
    rm ../backend/.env.tmp
    
    echo "✅ Updated backend/.env CORS configuration"
fi

echo ""
echo -e "${GREEN}🎉 Domain setup configuration complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Complete domain purchase at Cloudflare"
echo "2. Configure DNS records using: dns-config.txt"
echo "3. Apply security settings using: cloudflare-security-config.txt"
echo "4. Deploy to production with: ./deploy-production.sh"
echo ""
echo -e "${YELLOW}Important Files Created:${NC}"
echo "- dns-config.txt - DNS records to add in Cloudflare"
echo "- cloudflare-security-config.txt - Security settings to apply"
echo "- Configuration files updated for production deployment"
echo ""

# Final verification
echo -e "${BLUE}Verification Checklist:${NC}"
cat << EOF
□ Domain purchased at Cloudflare
□ DNS records configured
□ SSL certificates activated
□ Security settings applied
□ Production deployment ready
EOF

echo ""
echo -e "${GREEN}Your BookingBridge platform will be live at: https://${DOMAIN}${NC}"
echo "API endpoint: https://api.${DOMAIN}"
echo "Staging: https://staging.${DOMAIN}"
echo ""
echo "🚀 Ready for production deployment!"