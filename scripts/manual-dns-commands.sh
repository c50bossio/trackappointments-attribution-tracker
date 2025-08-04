#!/bin/bash
# Manual DNS Commands for TrackAppointments.com
# This script generates the exact commands you need to run

echo "🌐 DNS Setup Commands for trackappointments.com"
echo "=============================================="
echo ""

# Get user inputs
echo "I need some information to generate the DNS commands:"
echo ""

read -p "What's your server IP address? " SERVER_IP
read -p "What's your Cloudflare API token? " CF_TOKEN

echo ""
echo "Generating DNS commands..."
echo ""

# Set domain and zone info
DOMAIN="trackappointments.com"
API_BASE="https://api.cloudflare.com/client/v4"

echo "🔍 Step 1: Get Zone ID"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" \"$API_BASE/zones?name=$DOMAIN\" | jq -r '.result[0].id'"
echo ""

echo "📝 Step 2: Add DNS Records (replace ZONE_ID with result from step 1)"
echo ""

echo "# Main domain A record"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X POST \"$API_BASE/zones/ZONE_ID/dns_records\" -d '{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$SERVER_IP\",\"proxied\":true}'"
echo ""

echo "# WWW CNAME record"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X POST \"$API_BASE/zones/ZONE_ID/dns_records\" -d '{\"type\":\"CNAME\",\"name\":\"www.$DOMAIN\",\"content\":\"$DOMAIN\",\"proxied\":true}'"
echo ""

echo "# API A record"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X POST \"$API_BASE/zones/ZONE_ID/dns_records\" -d '{\"type\":\"A\",\"name\":\"api.$DOMAIN\",\"content\":\"$SERVER_IP\",\"proxied\":true}'"
echo ""

echo "# Staging A record"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X POST \"$API_BASE/zones/ZONE_ID/dns_records\" -d '{\"type\":\"A\",\"name\":\"staging.$DOMAIN\",\"content\":\"$SERVER_IP\",\"proxied\":true}'"
echo ""

echo "# Admin A record"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X POST \"$API_BASE/zones/ZONE_ID/dns_records\" -d '{\"type\":\"A\",\"name\":\"admin.$DOMAIN\",\"content\":\"$SERVER_IP\",\"proxied\":true}'"
echo ""

echo "🔒 Step 3: Configure SSL"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X PATCH \"$API_BASE/zones/ZONE_ID/settings/ssl\" -d '{\"value\":\"full\"}'"
echo ""

echo "🌐 Step 4: Enable Always HTTPS"
echo "curl -H \"Authorization: Bearer $CF_TOKEN\" -H \"Content-Type: application/json\" -X PATCH \"$API_BASE/zones/ZONE_ID/settings/always_use_https\" -d '{\"value\":\"on\"}'"
echo ""

echo "✅ After running these commands, your DNS will be configured!"
echo ""
echo "Your URLs will be:"
echo "• https://$DOMAIN"
echo "• https://api.$DOMAIN"
echo "• https://staging.$DOMAIN"
echo "• https://admin.$DOMAIN"