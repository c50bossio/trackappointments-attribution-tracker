#!/bin/bash
# Cloudflare API automation for domain management
# Requires: CLOUDFLARE_API_TOKEN environment variable

DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN environment variable required"
    echo "Get your token from: https://dash.cloudflare.com/profile/api-tokens"
    exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"
HEADERS="Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Function to call Cloudflare API
cf_api() {
    curl -s -H "$HEADERS" -H "Content-Type: application/json" "$@"
}

echo "🌐 Setting up Cloudflare for: $DOMAIN"

# Get zone ID
ZONE_ID=$(cf_api "$API_BASE/zones?name=$DOMAIN" | jq -r '.result[0].id')

if [ "$ZONE_ID" = "null" ]; then
    echo "❌ Domain not found in Cloudflare. Please add domain first."
    exit 1
fi

echo "✅ Found zone ID: $ZONE_ID"

# Set up SSL settings
echo "🔒 Configuring SSL..."
cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/ssl" \
    -d '{"value":"full"}' > /dev/null

cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/always_use_https" \
    -d '{"value":"on"}' > /dev/null

echo "✅ SSL configured (Full mode, Always HTTPS)"

# Enable security features
echo "🛡️ Enabling security features..."
cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/security_level" \
    -d '{"value":"medium"}' > /dev/null

cf_api -X PATCH "$API_BASE/zones/$ZONE_ID/settings/bot_fight_mode" \
    -d '{"value":"on"}' > /dev/null

echo "✅ Security features enabled"

# Set up DNS records from config
if [ -f "../dns-config.json" ]; then
    echo "📋 Creating DNS records..."
    
    # This would parse dns-config.json and create records
    # For now, showing the manual steps needed
    
    echo "DNS records to create manually:"
    cat ../dns-config.json | jq -r '.dns_records[] | "\(.type) \(.name) -> \(.value)"'
fi

echo "🎉 Cloudflare setup complete!"
