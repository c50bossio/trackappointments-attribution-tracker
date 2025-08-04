#!/bin/bash
# Deploy BookingBridge with custom domain

DOMAIN="bookingbridge.app"

echo "🚀 Deploying BookingBridge to: $DOMAIN"

# Build production images
docker-compose -f docker-compose.production.yml build

# Deploy with domain configuration
docker-compose -f docker-compose.production.yml up -d

# Health check
sleep 30
echo "🏥 Running health checks..."

# Check API
curl -f https://api.$DOMAIN/api/health || echo "❌ API health check failed"

# Check frontend  
curl -f https://$DOMAIN/ || echo "❌ Frontend health check failed"

echo "✅ Deployment complete!"
echo "🌐 Your platform is live at: https://$DOMAIN"
