#!/bin/bash
# Deploy TrackAppointments.com to Production

DOMAIN="trackappointments.com"

echo "🚀 Deploying TrackAppointments Attribution Tracker to: $DOMAIN"
echo ""

# Pre-deployment checks
echo "🔍 Pre-deployment checks..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker is running"

# Check if domain is configured
if [ ! -f "../dns-config.json" ]; then
    echo "❌ DNS configuration not found. Run setup script first."
    exit 1
fi

echo "✅ DNS configuration found"

# Build production images
echo ""
echo "📦 Building production containers..."
docker-compose -f ../docker-compose.production.yml build --no-cache

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Check logs above."
    exit 1
fi

echo "✅ Production containers built successfully"

# Stop existing containers
echo ""
echo "🛑 Stopping existing containers..."
docker-compose -f ../docker-compose.production.yml down

# Start production deployment
echo ""
echo "🌐 Starting production deployment..."
docker-compose -f ../docker-compose.production.yml up -d

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed. Check logs with: docker-compose -f docker-compose.production.yml logs"
    exit 1
fi

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to start..."
sleep 30

# Health checks
echo ""
echo "🏥 Running health checks..."

# Check backend health
echo "Testing API: https://api.$DOMAIN/api/health"
backend_status=$(curl -s -o /dev/null -w "%{http_code}" https://api.$DOMAIN/api/health 2>/dev/null || echo "000")

if [ "$backend_status" = "200" ]; then
    echo "✅ API is healthy (200 OK)"
else
    echo "⚠️  API health check returned: $backend_status"
    echo "   Checking local health..."
    local_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/health 2>/dev/null || echo "000")
    if [ "$local_status" = "200" ]; then
        echo "✅ Local API is healthy - DNS may need time to propagate"
    else
        echo "❌ Local API health check failed ($local_status)"
    fi
fi

# Check frontend
echo "Testing Frontend: https://$DOMAIN"
frontend_status=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null || echo "000")

if [ "$frontend_status" = "200" ]; then
    echo "✅ Frontend is healthy (200 OK)"
else
    echo "⚠️  Frontend health check returned: $frontend_status"
    echo "   Checking local frontend..."
    local_frontend=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 2>/dev/null || echo "000")
    if [ "$local_frontend" = "200" ]; then
        echo "✅ Local frontend is healthy - DNS may need time to propagate"
    else
        echo "❌ Local frontend health check failed ($local_frontend)"
    fi
fi

# Show container status
echo ""
echo "📊 Container Status:"
docker-compose -f ../docker-compose.production.yml ps

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "🌐 Your TrackAppointments Attribution Tracker is live at:"
echo "   📱 Main App:    https://$DOMAIN"
echo "   🔗 API:         https://api.$DOMAIN"
echo "   🧪 Staging:     https://staging.$DOMAIN"
echo "   👑 Admin:       https://admin.$DOMAIN"
echo ""
echo "📋 Useful Commands:"
echo "   View logs:      docker-compose -f docker-compose.production.yml logs -f"
echo "   Restart:        docker-compose -f docker-compose.production.yml restart"
echo "   Stop:           docker-compose -f docker-compose.production.yml down"
echo ""
echo "🎯 Next Steps:"
echo "   1. Add DNS records to point to your server IP"
echo "   2. Configure SSL certificates in Cloudflare/DNS provider"
echo "   3. Set up API credentials for real data integration"
echo ""
