#!/bin/bash
# Deploy BookingTracker to production domain

DOMAIN="bookingtracker.app"

echo "🚀 Deploying BookingTracker to: $DOMAIN"
echo ""

# Build production images
echo "📦 Building production containers..."
docker-compose -f docker-compose.production.yml build

# Deploy to production
echo "🌐 Starting production deployment..."
docker-compose -f docker-compose.production.yml up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 30

# Health checks
echo "🏥 Running health checks..."
echo ""

# Test API
echo "Testing API: https://api.$DOMAIN/api/health"
curl -f -s https://api.$DOMAIN/api/health > /dev/null && echo "✅ API is healthy" || echo "❌ API health check failed"

# Test frontend
echo "Testing Frontend: https://$DOMAIN"
curl -f -s https://$DOMAIN > /dev/null && echo "✅ Frontend is healthy" || echo "❌ Frontend health check failed"

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "🌐 Your BookingTracker platform is live at:"
echo "   Main App: https://$DOMAIN"
echo "   API:      https://api.$DOMAIN"
echo "   Staging:  https://staging.$DOMAIN"
echo "   Admin:    https://admin.$DOMAIN"
echo ""
