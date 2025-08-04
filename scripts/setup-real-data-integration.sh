#!/bin/bash
# BookingBridge Real Data Integration Setup Script
# Helps users configure API credentials for production use

set -e

echo "🚀 BookingBridge Real Data Integration Setup"
echo "============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env file exists
ENV_FILE="../backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Please ensure you're running this script from the scripts/ directory"
    exit 1
fi

echo -e "${BLUE}Current integration status:${NC}"
echo ""

# Check Facebook Ads configuration
if grep -q "FACEBOOK_APP_ID=" "$ENV_FILE" && grep -q "FACEBOOK_APP_SECRET=" "$ENV_FILE"; then
    if grep -q "FACEBOOK_APP_ID=$" "$ENV_FILE" || grep -q "FACEBOOK_APP_SECRET=$" "$ENV_FILE"; then
        echo -e "📱 Facebook Ads API: ${YELLOW}Not configured${NC}"
        FACEBOOK_CONFIGURED=false
    else
        echo -e "📱 Facebook Ads API: ${GREEN}Configured${NC}"
        FACEBOOK_CONFIGURED=true
    fi
else
    echo -e "📱 Facebook Ads API: ${RED}Missing environment variables${NC}"
    FACEBOOK_CONFIGURED=false
fi

# Check Square configuration  
if grep -q "SQUARE_APPLICATION_ID=" "$ENV_FILE" && grep -q "SQUARE_ACCESS_TOKEN=" "$ENV_FILE"; then
    if grep -q "SQUARE_APPLICATION_ID=$" "$ENV_FILE" || grep -q "SQUARE_ACCESS_TOKEN=$" "$ENV_FILE"; then
        echo -e "🏪 Square Booking API: ${YELLOW}Not configured${NC}"
        SQUARE_CONFIGURED=false
    else
        echo -e "🏪 Square Booking API: ${GREEN}Configured${NC}"
        SQUARE_CONFIGURED=true
    fi
else
    echo -e "🏪 Square Booking API: ${RED}Missing environment variables${NC}"
    SQUARE_CONFIGURED=false
fi

# Check Google Ads configuration
if grep -q "GOOGLE_ADS_DEVELOPER_TOKEN=" "$ENV_FILE" && grep -q "GOOGLE_ADS_CLIENT_ID=" "$ENV_FILE"; then
    if grep -q "GOOGLE_ADS_DEVELOPER_TOKEN=$" "$ENV_FILE" || grep -q "GOOGLE_ADS_CLIENT_ID=$" "$ENV_FILE"; then
        echo -e "🔍 Google Ads API: ${YELLOW}Not configured${NC}"
        GOOGLE_CONFIGURED=false
    else
        echo -e "🔍 Google Ads API: ${GREEN}Configured${NC}"
        GOOGLE_CONFIGURED=true
    fi
else
    echo -e "🔍 Google Ads API: ${RED}Missing environment variables${NC}"
    GOOGLE_CONFIGURED=false
fi

echo ""

# If all configured, show success
if [ "$FACEBOOK_CONFIGURED" = true ] && [ "$SQUARE_CONFIGURED" = true ] && [ "$GOOGLE_CONFIGURED" = true ]; then
    echo -e "${GREEN}✅ All integrations are configured!${NC}"
    echo "Your platform is ready to process real business data."
    echo ""
    echo "Next steps:"
    echo "1. Restart your backend server to load new credentials"
    echo "2. Test API connections using /api/v1/integrations/status"
    echo "3. Verify webhook endpoints are accessible"
    exit 0
fi

# Interactive configuration
echo -e "${YELLOW}⚠️  Some integrations need configuration.${NC}"
echo ""
read -p "Would you like to configure missing integrations now? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. You can run this script again anytime."
    exit 0
fi

echo ""
echo "🔧 Starting interactive configuration..."
echo ""

# Facebook Ads setup
if [ "$FACEBOOK_CONFIGURED" = false ]; then
    echo -e "${BLUE}📱 Configuring Facebook Ads API${NC}"
    echo "Follow these steps to get your Facebook Ads credentials:"
    echo ""
    echo "1. Go to https://developers.facebook.com/apps/"
    echo "2. Create a new app or select existing app"
    echo "3. Add 'Marketing API' product"
    echo "4. Generate an access token with ads_read permissions"
    echo ""
    
    read -p "Enter your Facebook App ID: " FACEBOOK_APP_ID
    read -p "Enter your Facebook App Secret: " FACEBOOK_APP_SECRET
    read -p "Enter your Facebook Access Token: " FACEBOOK_ACCESS_TOKEN
    
    # Update .env file
    sed -i.bak "s/FACEBOOK_APP_ID=.*/FACEBOOK_APP_ID=$FACEBOOK_APP_ID/" "$ENV_FILE"
    sed -i.bak "s/FACEBOOK_APP_SECRET=.*/FACEBOOK_APP_SECRET=$FACEBOOK_APP_SECRET/" "$ENV_FILE"
    sed -i.bak "s/FACEBOOK_ACCESS_TOKEN=.*/FACEBOOK_ACCESS_TOKEN=$FACEBOOK_ACCESS_TOKEN/" "$ENV_FILE"
    
    echo -e "${GREEN}✅ Facebook Ads API configured${NC}"
    echo ""
fi

# Square setup
if [ "$SQUARE_CONFIGURED" = false ]; then
    echo -e "${BLUE}🏪 Configuring Square Booking API${NC}"
    echo "Follow these steps to get your Square credentials:"
    echo ""
    echo "1. Go to https://developer.squareup.com/apps"
    echo "2. Create a new application or select existing"
    echo "3. Get your Application ID and Access Token"
    echo "4. Set up webhook endpoints for booking events"
    echo ""
    
    read -p "Enter your Square Application ID: " SQUARE_APPLICATION_ID
    read -p "Enter your Square Access Token: " SQUARE_ACCESS_TOKEN
    read -p "Enter your Square Webhook Signature Key (optional): " SQUARE_WEBHOOK_KEY
    
    # Update .env file
    sed -i.bak "s/SQUARE_APPLICATION_ID=.*/SQUARE_APPLICATION_ID=$SQUARE_APPLICATION_ID/" "$ENV_FILE"
    sed -i.bak "s/SQUARE_ACCESS_TOKEN=.*/SQUARE_ACCESS_TOKEN=$SQUARE_ACCESS_TOKEN/" "$ENV_FILE"
    sed -i.bak "s/SQUARE_WEBHOOK_SIGNATURE_KEY=.*/SQUARE_WEBHOOK_SIGNATURE_KEY=$SQUARE_WEBHOOK_KEY/" "$ENV_FILE"
    
    echo -e "${GREEN}✅ Square Booking API configured${NC}"
    echo ""
fi

# Google Ads setup
if [ "$GOOGLE_CONFIGURED" = false ]; then
    echo -e "${BLUE}🔍 Configuring Google Ads API${NC}"
    echo "Google Ads API setup is more complex and requires:"
    echo ""
    echo "1. Google Ads API developer token (requires approval)"
    echo "2. OAuth 2.0 credentials from Google Cloud Console"
    echo "3. Refresh token from OAuth flow"
    echo ""
    echo "For detailed setup instructions, see:"
    echo "https://developers.google.com/google-ads/api"
    echo ""
    
    read -p "Do you have Google Ads API credentials ready? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your Google Ads Developer Token: " GOOGLE_DEVELOPER_TOKEN
        read -p "Enter your Google Ads Client ID: " GOOGLE_CLIENT_ID
        read -p "Enter your Google Ads Client Secret: " GOOGLE_CLIENT_SECRET
        read -p "Enter your Google Ads Refresh Token: " GOOGLE_REFRESH_TOKEN
        
        # Update .env file
        sed -i.bak "s/GOOGLE_ADS_DEVELOPER_TOKEN=.*/GOOGLE_ADS_DEVELOPER_TOKEN=$GOOGLE_DEVELOPER_TOKEN/" "$ENV_FILE"
        sed -i.bak "s/GOOGLE_ADS_CLIENT_ID=.*/GOOGLE_ADS_CLIENT_ID=$GOOGLE_CLIENT_ID/" "$ENV_FILE"
        sed -i.bak "s/GOOGLE_ADS_CLIENT_SECRET=.*/GOOGLE_ADS_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET/" "$ENV_FILE"
        sed -i.bak "s/GOOGLE_ADS_REFRESH_TOKEN=.*/GOOGLE_ADS_REFRESH_TOKEN=$GOOGLE_REFRESH_TOKEN/" "$ENV_FILE"
        
        echo -e "${GREEN}✅ Google Ads API configured${NC}"
    else
        echo -e "${YELLOW}⏭️  Skipping Google Ads API configuration${NC}"
        echo "You can configure this later using the same process."
    fi
    echo ""
fi

# Clean up backup files
rm -f "$ENV_FILE.bak"

echo ""
echo -e "${GREEN}🎉 Configuration complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Install new Python dependencies: pip install -r ../backend/requirements.txt"
echo "2. Restart your backend server: docker-compose restart backend"
echo "3. Test integrations: curl http://localhost:8001/api/v1/integrations/status"
echo "4. Check your dashboard at http://localhost:3001"
echo ""
echo -e "${BLUE}📚 For troubleshooting and advanced setup:${NC}"
echo "See REAL_DATA_INTEGRATION_PLAN.md for detailed instructions"
echo ""
echo -e "${GREEN}✨ Your BookingBridge platform is ready for real data!${NC}"