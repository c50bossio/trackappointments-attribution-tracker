#!/bin/bash
# Automated DNS Setup for TrackAppointments.com

set -e

DOMAIN="trackappointments.com"
API_BASE="https://api.cloudflare.com/client/v4"

echo "🌐 Automated DNS Setup for $DOMAIN"
echo "=================================="
echo ""

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is required but not installed"
    exit 1
fi

# Get credentials
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    read -p "Enter your Cloudflare API Token: " CLOUDFLARE_API_TOKEN
fi

if [ -z "$SERVER_IP" ]; then
    read -p "Enter your server IP address: " SERVER_IP
fi

echo ""
echo "🔍 Getting zone ID..."

# Get zone ID
ZONE_RESPONSE=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$API_BASE/zones?name=$DOMAIN")
ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id // "null"')

if [ "$ZONE_ID" = "null" ]; then
    echo "❌ Could not find zone for $DOMAIN"
    echo "Response: $ZONE_RESPONSE"
    exit 1
fi

echo "✅ Zone ID: $ZONE_ID"

# Function to add/update DNS record
add_record() {
    local type="$1"
    local name="$2"
    local content="$3"
    local proxied="$4"
    
    echo "📝 Adding $type record: $name -> $content"
    
    # Check if record exists
    existing=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$API_BASE/zones/$ZONE_ID/dns_records?name=$name&type=$type")
    existing_id=$(echo "$existing" | jq -r '.result[0].id // "null"')
    
    if [ "$existing_id" != "null" ]; then
        # Update existing record
        result=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" -X PUT "$API_BASE/zones/$ZONE_ID/dns_records/$existing_id" -d "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}")
    else
        # Create new record
        result=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" -X POST "$API_BASE/zones/$ZONE_ID/dns_records" -d "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"proxied\":$proxied}")
    fi
    
    success=$(echo "$result" | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo "   ✅ Success"
    else
        echo "   ❌ Failed: $(echo "$result" | jq -r '.errors[0].message // "Unknown error"')"
    fi
}

echo ""
echo "📝 Adding DNS records..."

# Add DNS records
add_record "A" "$DOMAIN" "$SERVER_IP" "true"
add_record "CNAME" "www.$DOMAIN" "$DOMAIN" "true"
add_record "A" "api.$DOMAIN" "$SERVER_IP" "true"
add_record "A" "staging.$DOMAIN" "$SERVER_IP" "true"
add_record "A" "admin.$DOMAIN" "$SERVER_IP" "true"

echo ""
echo "🔒 Configuring SSL..."

# Configure SSL
ssl_result=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" -X PATCH "$API_BASE/zones/$ZONE_ID/settings/ssl" -d '{"value":"full"}')
ssl_success=$(echo "$ssl_result" | jq -r '.success')

if [ "$ssl_success" = "true" ]; then
    echo "✅ SSL configured (Full mode)"
else
    echo "⚠️  SSL configuration may need manual setup"
fi

# Enable Always HTTPS
https_result=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" -X PATCH "$API_BASE/zones/$ZONE_ID/settings/always_use_https" -d '{"value":"on"}')
https_success=$(echo "$https_result" | jq -r '.success')

if [ "$https_success" = "true" ]; then
    echo "✅ Always HTTPS enabled"
else
    echo "⚠️  HTTPS redirect may need manual setup"
fi

echo ""
echo "🎉 DNS Setup Complete!"
echo ""
echo "Your TrackAppointments platform will be available at:"
echo "• https://$DOMAIN"
echo "• https://api.$DOMAIN"
echo "• https://staging.$DOMAIN"
echo "• https://admin.$DOMAIN"
echo ""
echo "DNS propagation may take 1-5 minutes."
echo ""
echo "Ready to deploy: ./deploy-trackappointments.sh"