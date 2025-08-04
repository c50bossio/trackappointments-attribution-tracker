#!/bin/bash
# Test Cloudflare API Token Permissions

echo "🔍 Testing Cloudflare API Token Permissions"
echo "==========================================="
echo ""

read -p "Enter your Cloudflare API Token: " CF_TOKEN
echo ""

DOMAIN="trackappointments.com"
API_BASE="https://api.cloudflare.com/client/v4"

echo "1. Testing token validity..."
token_test=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "$API_BASE/user/tokens/verify")
echo "Token test result: $token_test" | jq '.'
echo ""

echo "2. Testing zone access..."
zone_test=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "$API_BASE/zones?name=$DOMAIN")
echo "Zone test result: $zone_test" | jq '.'
echo ""

ZONE_ID=$(echo "$zone_test" | jq -r '.result[0].id // "null"')

if [ "$ZONE_ID" != "null" ]; then
    echo "✅ Zone ID found: $ZONE_ID"
    echo ""
    
    echo "3. Testing DNS record list (should work if token is correct)..."
    dns_list=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "$API_BASE/zones/$ZONE_ID/dns_records")
    echo "DNS list result: $dns_list" | jq '.'
    echo ""
    
    echo "4. Testing DNS record creation (the actual test)..."
    test_record=$(curl -s -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" -X POST "$API_BASE/zones/$ZONE_ID/dns_records" -d '{"type":"TXT","name":"test.trackappointments.com","content":"token-test","ttl":120}')
    echo "DNS creation test: $test_record" | jq '.'
    
    # Clean up test record if it was created
    test_id=$(echo "$test_record" | jq -r '.result.id // "null"')
    if [ "$test_id" != "null" ]; then
        echo ""
        echo "5. Cleaning up test record..."
        cleanup=$(curl -s -H "Authorization: Bearer $CF_TOKEN" -X DELETE "$API_BASE/zones/$ZONE_ID/dns_records/$test_id")
        echo "Cleanup result: $cleanup" | jq '.'
    fi
else
    echo "❌ Could not find zone"
fi

echo ""
echo "🎯 Analysis:"
echo "If you see 'success: true' in the DNS creation test, your token works!"
echo "If you see 'Authentication error', the token needs more permissions."