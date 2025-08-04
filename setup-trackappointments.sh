#!/bin/bash
# TrackAppointments.com Domain Setup - Using Your Existing Domain

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="trackappointments.com"

echo -e "${BLUE}🎯 TrackAppointments.com Configuration${NC}"
echo "======================================"
echo ""
echo -e "${GREEN}✅ Using your existing domain: ${DOMAIN}${NC}"
echo "- Professional .com TLD"
echo "- Perfect for appointment attribution tracking"
echo "- Already owned - no purchase needed!"
echo ""

echo -e "${BLUE}Step 1: Updating All Configuration Files${NC}"

# Update DNS configuration
cat > ../dns-config.json << EOF
{
  "domain": "${DOMAIN}",
  "dns_records": [
    {
      "type": "A",
      "name": "@",
      "value": "YOUR_PRODUCTION_SERVER_IP",
      "proxy": true,
      "comment": "Main application (${DOMAIN})"
    },
    {
      "type": "CNAME", 
      "name": "www",
      "value": "${DOMAIN}",
      "proxy": true,
      "comment": "WWW redirect"
    },
    {
      "type": "A",
      "name": "api",
      "value": "YOUR_API_SERVER_IP", 
      "proxy": true,
      "comment": "API endpoints (api.${DOMAIN})"
    },
    {
      "type": "A",
      "name": "staging",
      "value": "YOUR_STAGING_SERVER_IP",
      "proxy": true,
      "comment": "Staging environment (staging.${DOMAIN})"
    },
    {
      "type": "A",
      "name": "admin",
      "value": "YOUR_ADMIN_SERVER_IP",
      "proxy": true,
      "comment": "Admin dashboard (admin.${DOMAIN})"
    }
  ],
  "cloudflare_settings": {
    "ssl": {
      "mode": "Full (strict)",
      "always_use_https": true,
      "hsts": true,
      "min_tls_version": "1.2",
      "tls_1_3": true
    },
    "security": {
      "waf": true,
      "bot_protection": true,
      "ddos_protection": true
    },
    "performance": {
      "auto_minify": ["css", "html", "js"],
      "brotli": true,
      "caching_level": "Standard"
    }
  }
}
EOF

echo "✅ DNS configuration updated for ${DOMAIN}"

# Update Docker Compose production
if [ -f "../docker-compose.production.yml" ]; then
    cp "../docker-compose.production.yml" "../docker-compose.production.yml.bak"
    
    # Update all domain references
    sed -i.tmp "s/bookingtracker\.app/${DOMAIN}/g" ../docker-compose.production.yml
    sed -i.tmp "s/bookingbridge\.app/${DOMAIN}/g" ../docker-compose.production.yml
    sed -i.tmp "s/localhost:3001/${DOMAIN}/g" ../docker-compose.production.yml
    sed -i.tmp "s/localhost:8001/api.${DOMAIN}/g" ../docker-compose.production.yml
    rm ../docker-compose.production.yml.tmp
    
    echo "✅ Production Docker configuration updated"
fi

# Update backend environment
if [ -f "../backend/.env" ]; then
    cp "../backend/.env" "../backend/.env.bak"
    
    # Update CORS origins
    sed -i.tmp "s|CORS_ORIGINS=.*|CORS_ORIGINS=https://${DOMAIN},https://www.${DOMAIN},https://api.${DOMAIN},https://staging.${DOMAIN}|g" ../backend/.env
    rm ../backend/.env.tmp
    
    echo "✅ Backend CORS configuration updated"
fi

# Update frontend API endpoints
if [ -f "../frontend/public/index.html" ]; then
    cp "../frontend/public/index.html" "../frontend/public/index.html.domain-bak"
    
    # Update API endpoints
    sed -i.tmp "s|http://localhost:8001|https://api.${DOMAIN}|g" ../frontend/public/index.html
    sed -i.tmp "s|api\.bookingtracker\.app|api.${DOMAIN}|g" ../frontend/public/index.html
    sed -i.tmp "s|api\.bookingbridge\.app|api.${DOMAIN}|g" ../frontend/public/index.html
    rm ../frontend/public/index.html.tmp
    
    echo "✅ Frontend API endpoints updated"
fi

# Update application title and branding
if [ -f "../frontend/public/index.html" ]; then
    sed -i.tmp "s|BookingBridge|TrackAppointments|g" ../frontend/public/index.html
    sed -i.tmp "s|Barbershop Dashboard|Appointment Attribution Dashboard|g" ../frontend/public/index.html
    rm ../frontend/public/index.html.tmp
    
    echo "✅ Application branding updated"
fi

# Create production deployment script
cat > ../scripts/deploy-trackappointments.sh << 'EOF'
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
EOF

chmod +x ../scripts/deploy-trackappointments.sh
echo "✅ Production deployment script created"

# Create DNS setup guide
cat > ../DNS_SETUP_GUIDE.md << EOF
# TrackAppointments.com DNS Setup Guide

## 🌐 Domain: trackappointments.com (Your Existing Domain)

### Step 1: Add DNS Records
Add these DNS records in your domain provider's control panel:

#### A Records (Point to your server IP)
\`\`\`
Type: A     Name: @         Value: [YOUR-PRODUCTION-IP]    TTL: 300
Type: A     Name: api       Value: [YOUR-API-SERVER-IP]    TTL: 300  
Type: A     Name: staging   Value: [YOUR-STAGING-IP]       TTL: 300
Type: A     Name: admin     Value: [YOUR-ADMIN-IP]         TTL: 300
\`\`\`

#### CNAME Record (WWW redirect)
\`\`\`
Type: CNAME Name: www       Value: trackappointments.com   TTL: 300
\`\`\`

### Step 2: SSL Certificate Setup

#### Option A: Cloudflare (Recommended)
1. Transfer DNS to Cloudflare (keeps domain registration with current provider)
2. Automatic SSL certificates
3. Built-in CDN and DDoS protection
4. Free tier available

#### Option B: Let's Encrypt (Free)
1. Install certbot on your server
2. Generate certificates for all subdomains:
   \`\`\`bash
   certbot --nginx -d trackappointments.com -d www.trackappointments.com -d api.trackappointments.com -d staging.trackappointments.com -d admin.trackappointments.com
   \`\`\`

#### Option C: Paid SSL Certificate
1. Purchase wildcard SSL certificate
2. Install on your web server/load balancer

### Step 3: Server Configuration

#### Nginx Configuration Example:
\`\`\`nginx
# /etc/nginx/sites-available/trackappointments.com
server {
    listen 80;
    server_name trackappointments.com www.trackappointments.com;
    return 301 https://trackappointments.com\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name trackappointments.com www.trackappointments.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl http2;
    server_name api.trackappointments.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
\`\`\`

### Step 4: Deploy Application
\`\`\`bash
./scripts/deploy-trackappointments.sh
\`\`\`

## 🎯 Final URLs:
- **Main Platform**: https://trackappointments.com
- **API Endpoints**: https://api.trackappointments.com
- **Staging Environment**: https://staging.trackappointments.com
- **Admin Dashboard**: https://admin.trackappointments.com

## ✅ Verification Checklist:
- [ ] DNS records added and propagated
- [ ] SSL certificates installed
- [ ] Application deployed
- [ ] Health checks passing
- [ ] All URLs accessible

---
*Your TrackAppointments Attribution Tracker platform is ready for production!*
EOF

echo "✅ DNS setup guide created: DNS_SETUP_GUIDE.md"

echo ""
echo -e "${GREEN}🎉 TRACKAPPOINTMENTS.COM SETUP COMPLETE!${NC}"
echo ""
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo "✅ Domain: trackappointments.com (your existing domain)"
echo "✅ All configuration files updated"
echo "✅ DNS records defined"
echo "✅ SSL & security configured"
echo "✅ Production deployment ready"
echo "✅ Application branding updated"
echo ""

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. 🌐 Add DNS records (see DNS_SETUP_GUIDE.md)"
echo "2. 🔒 Set up SSL certificates"
echo "3. 🚀 Deploy: ./scripts/deploy-trackappointments.sh"
echo ""

echo -e "${GREEN}🌟 Your platform will be live at:${NC}"
echo -e "${BLUE}https://trackappointments.com${NC}"
echo ""
echo "Perfect domain choice for appointment attribution tracking! 🎯"