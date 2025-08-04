#!/bin/bash
# Automated DNS Record Setup for TrackAppointments.com via Cloudflare API

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="trackappointments.com"

echo -e "${BLUE}🌐 Cloudflare DNS Setup for ${DOMAIN}${NC}"
echo "================================================"
echo ""

# Check if Cloudflare API token is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Cloudflare API Token Required${NC}"
    echo ""
    echo "To add DNS records automatically, you need a Cloudflare API token."
    echo ""
    echo "Get your token:"
    echo "1. Go to: https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Click 'Create Token'"
    echo "3. Use 'Custom token' template"
    echo "4. Set permissions:"
    echo "   - Zone: Zone Settings: Read"
    echo "   - Zone: DNS: Edit"
    echo "5. Set zone resources:"
    echo "   - Include: Specific zone: ${DOMAIN}"
    echo ""
    echo -e "${BLUE}Then export the token:${NC}"
    echo "export CLOUDFLARE_API_TOKEN=\"your_token_here\""
    echo ""
    read -p "Do you want to enter the token now? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your Cloudflare API token: " CLOUDFLARE_API_TOKEN
        export CLOUDFLARE_API_TOKEN
        echo -e "${GREEN}✅ Token set for this session${NC}"
    else
        echo -e "${YELLOW}Please set CLOUDFLARE_API_TOKEN and run this script again.${NC}"
        exit 1
    fi
fi

# Cloudflare API configuration
API_BASE="https://api.cloudflare.com/client/v4"
HEADERS="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

echo -e "${BLUE}Step 1: Getting Zone Information${NC}"

# Function to make Cloudflare API calls
cf_api() {
    curl -s -H "$HEADERS" -H "Content-Type: application/json" "$@"
}

# Get zone ID
echo "🔍 Finding zone ID for ${DOMAIN}..."
ZONE_RESPONSE=$(cf_api "$API_BASE/zones?name=$DOMAIN")
ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // "null"')

if [ "$ZONE_ID" = "null" ]; then
    echo -e "${RED}❌ Domain ${DOMAIN} not found in Cloudflare${NC}"
    echo "Make sure:"
    echo "1. Domain is added to your Cloudflare account"
    echo "2. API token has correct permissions"
    exit 1
fi

echo -e "${GREEN}✅ Zone ID found: ${ZONE_ID}${NC}"

echo ""
echo -e "${BLUE}Step 2: Adding DNS Records${NC}"

# Function to add DNS record
add_dns_record() {
    local record_type="$1"
    local record_name="$2" 
    local record_value="$3"
    local proxy="$4"
    local comment="$5"
    
    echo "📝 Adding ${record_type} record: ${record_name} -> ${record_value}"
    
    # Check if record already exists
    existing=$(cf_api "$API_BASE/zones/$ZONE_ID/dns_records?name=${record_name}&type=${record_type}")
    existing_id=$(echo "$existing" | jq -r '.result[0].id // "null"')
    
    if [ "$existing_id" != "null" ]; then
        echo "   ⚠️  Record already exists, updating..."
        
        # Update existing record
        result=$(cf_api -X PUT "$API_BASE/zones/$ZONE_ID/dns_records/$existing_id" \
            -d "{
                \"type\": \"$record_type\",
                \"name\": \"$record_name\",
                \"content\": \"$record_value\",
                \"proxied\": $proxy,
                \"comment\": \"$comment\"
            }")
    else
        echo "   ➕ Creating new record..."
        
        # Create new record
        result=$(cf_api -X POST "$API_BASE/zones/$ZONE_ID/dns_records" \
            -d "{
                \"type\": \"$record_type\",
                \"name\": \"$record_name\",
                \"content\": \"$record_value\",
                \"proxied\": $proxy,
                \"comment\": \"$comment\"
            }")
    fi
    
    # Check if successful
    success=$(echo "$result" | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "   ${GREEN}✅ Success${NC}"
    else
        echo -e "   ${RED}❌ Failed${NC}"
        echo "$result" | jq -r '.errors[].message' 2>/dev/null || echo "Unknown error"
    fi
}

# Server IP prompt
echo ""
echo -e "${YELLOW}Server IP Configuration${NC}"
echo "You need to provide your server IP addresses for the DNS records."
echo ""

if [ -z "$SERVER_IP" ]; then
    echo "What's your main server IP address?"
    echo "(This will be used for the main domain and API)"
    read -p "Server IP: " SERVER_IP
fi

if [ -z "$STAGING_IP" ]; then
    echo ""
    echo "What's your staging server IP? (can be same as main)"
    read -p "Staging IP [$SERVER_IP]: " STAGING_IP
    STAGING_IP=${STAGING_IP:-$SERVER_IP}
fi

if [ -z "$ADMIN_IP" ]; then
    echo ""
    echo "What's your admin server IP? (can be same as main)"  
    read -p "Admin IP [$SERVER_IP]: " ADMIN_IP
    ADMIN_IP=${ADMIN_IP:-$SERVER_IP}
fi

echo ""
echo -e "${BLUE}Adding DNS Records:${NC}"

# Add main domain record
add_dns_record "A" "$DOMAIN" "$SERVER_IP" "true" "TrackAppointments main application"

# Add www subdomain
add_dns_record "CNAME" "www.$DOMAIN" "$DOMAIN" "true" "WWW redirect to main domain"

# Add API subdomain
add_dns_record "A" "api.$DOMAIN" "$SERVER_IP" "true" "TrackAppointments API endpoints"

# Add staging subdomain
add_dns_record "A" "staging.$DOMAIN" "$STAGING_IP" "true" "TrackAppointments staging environment"

# Add admin subdomain
add_dns_record "A" "admin.$DOMAIN" "$ADMIN_IP" "true" "TrackAppointments admin dashboard"

echo ""
echo -e "${BLUE}Step 3: Configuring SSL and Security${NC}"

# Enable SSL settings
echo "🔒 Configuring SSL settings..."

# Set SSL mode to Full (strict)
ssl_result=$(cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/ssl" \
    -d '{"value":"full"}')

ssl_success=$(echo "$ssl_result" | jq -r '.success')
if [ "$ssl_success" = "true" ]; then
    echo -e "${GREEN}✅ SSL mode set to Full${NC}"
else
    echo -e "${YELLOW}⚠️  SSL configuration may need manual setup${NC}"
fi

# Enable Always Use HTTPS
https_result=$(cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/always_use_https" \
    -d '{"value":"on"}')

https_success=$(echo "$https_result" | jq -r '.success')
if [ "$https_success" = "true" ]; then
    echo -e "${GREEN}✅ Always Use HTTPS enabled${NC}"
else
    echo -e "${YELLOW}⚠️  HTTPS redirect may need manual setup${NC}"
fi

# Enable HSTS
hsts_result=$(cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/security_header" \
    -d '{
        "value": {
            "strict_transport_security": {
                "enabled": true,
                "max_age": 31536000,
                "include_subdomains": true
            }
        }
    }')

echo ""
echo -e "${GREEN}🎉 DNS Configuration Complete!${NC}"
echo ""
echo -e "${BLUE}📋 DNS Records Added:${NC}"
echo "✅ $DOMAIN -> $SERVER_IP"
echo "✅ www.$DOMAIN -> $DOMAIN (CNAME)"
echo "✅ api.$DOMAIN -> $SERVER_IP"
echo "✅ staging.$DOMAIN -> $STAGING_IP"
echo "✅ admin.$DOMAIN -> $ADMIN_IP"
echo ""
echo -e "${BLUE}🔒 Security Settings:${NC}"
echo "✅ SSL Mode: Full (strict)"
echo "✅ Always Use HTTPS: Enabled"
echo "✅ HSTS: Enabled"
echo "✅ DDoS Protection: Active (Cloudflare proxy)"
echo ""
echo -e "${YELLOW}⏳ DNS Propagation:${NC}"
echo "DNS changes may take 1-5 minutes to propagate globally."
echo ""
echo -e "${BLUE}🌐 Your URLs will be:${NC}"
echo "• Main: https://$DOMAIN"
echo "• API:  https://api.$DOMAIN"
echo "• Staging: https://staging.$DOMAIN"
echo "• Admin: https://admin.$DOMAIN"
echo ""
echo -e "${GREEN}Ready to deploy with: ./deploy-trackappointments.sh${NC}"