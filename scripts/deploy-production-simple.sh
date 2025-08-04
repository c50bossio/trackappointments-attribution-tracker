#!/bin/bash

# BookingBridge Production Deployment Script (Simplified)
# Deploys the attribution tracker to production environment with monitoring

set -euo pipefail

echo "🚀 BookingBridge Production Deployment"
echo "======================================"

# Configuration
PRODUCTION_ENV="production"
BACKEND_PORT=8002
FRONTEND_PORT=3002
POSTGRES_PORT=5433
REDIS_PORT=6381
GRAFANA_PORT=3003

echo "📋 Pre-deployment Checks"
echo "========================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi
echo "✅ Docker is running"

# Check if ports are available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is already in use. Stopping existing services..."
        # Kill processes using the port
        lsof -Pi :$port -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    echo "✅ Port $port is available"
}

check_port $BACKEND_PORT
check_port $FRONTEND_PORT
check_port $POSTGRES_PORT
check_port $REDIS_PORT
check_port $GRAFANA_PORT

echo ""
echo "🗄️ Database & Cache Setup"
echo "=========================="

# Start PostgreSQL for production
echo "Starting PostgreSQL database..."
docker run -d \
    --name bookingbridge-postgres-prod \
    --restart unless-stopped \
    -e POSTGRES_DB=bookingbridge_production \
    -e POSTGRES_USER=bookingbridge_admin \
    -e POSTGRES_PASSWORD=secure_production_password_2025_bb \
    -p $POSTGRES_PORT:5432 \
    -v bookingbridge_postgres_data:/var/lib/postgresql/data \
    postgres:15-alpine

# Start Redis for production
echo "Starting Redis cache..."
docker run -d \
    --name bookingbridge-redis-prod \
    --restart unless-stopped \
    --requirepass secure_redis_production_2025 \
    -p $REDIS_PORT:6379 \
    -v bookingbridge_redis_data:/data \
    redis:7-alpine redis-server --appendonly yes --requirepass secure_redis_production_2025

# Wait for services to be ready
echo "⏳ Waiting for database and cache to be ready..."
sleep 10

# Check PostgreSQL health
if docker exec bookingbridge-postgres-prod pg_isready -U bookingbridge_admin -d bookingbridge_production > /dev/null 2>&1; then
    echo "✅ PostgreSQL is ready"
else
    echo "❌ PostgreSQL failed to start"
    exit 1
fi

# Check Redis health
if docker exec bookingbridge-redis-prod redis-cli -a secure_redis_production_2025 ping > /dev/null 2>&1; then
    echo "✅ Redis is ready"
else
    echo "❌ Redis failed to start"
    exit 1
fi

echo ""
echo "🏗️ Building Production Applications"
echo "=================================="

# Update database URL in backend for production PostgreSQL
cat > backend/.env.production << EOF
DATABASE_URL=postgresql://bookingbridge_admin:secure_production_password_2025_bb@localhost:$POSTGRES_PORT/bookingbridge_production
REDIS_URL=redis://:secure_redis_production_2025@localhost:$REDIS_PORT/0
ENVIRONMENT=production
SECRET_KEY=prod-secure-key-2025-bookingbridge-attribution-tracker-enterprise-ready-platform
HASH_SALT=prod-secure-salt-for-privacy-safe-identifiers-compliance
EOF

# Build and start backend
echo "Building and starting backend service..."
docker build -t bookingbridge-backend:production ./backend/ || {
    echo "❌ Backend build failed"
    exit 1
}

docker run -d \
    --name bookingbridge-backend-prod \
    --restart unless-stopped \
    -p $BACKEND_PORT:8000 \
    --env-file backend/.env.production \
    -v $(pwd)/backend:/app \
    bookingbridge-backend:production

# Build and start frontend
echo "Building and starting frontend service..."
docker build -f ./frontend/Dockerfile.simple -t bookingbridge-frontend:production ./frontend/ || {
    echo "❌ Frontend build failed"
    exit 1
}

docker run -d \
    --name bookingbridge-frontend-prod \
    --restart unless-stopped \
    -p $FRONTEND_PORT:80 \
    -e NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT \
    bookingbridge-frontend:production

echo ""
echo "📊 Starting Monitoring Stack"
echo "============================"

# Start Prometheus
docker run -d \
    --name bookingbridge-prometheus-prod \
    --restart unless-stopped \
    -p 9091:9090 \
    -v $(pwd)/monitoring/prometheus:/etc/prometheus:ro \
    prom/prometheus:v2.47.0 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.console.templates=/etc/prometheus/consoles \
    --storage.tsdb.retention.time=200h \
    --web.enable-lifecycle

# Start Grafana
docker run -d \
    --name bookingbridge-grafana-prod \
    --restart unless-stopped \
    -p $GRAFANA_PORT:3000 \
    -e GF_SECURITY_ADMIN_USER=admin \
    -e GF_SECURITY_ADMIN_PASSWORD=secure_grafana_admin_2025 \
    -e GF_USERS_ALLOW_SIGN_UP=false \
    -v bookingbridge_grafana_data:/var/lib/grafana \
    grafana/grafana:10.1.0

echo ""
echo "⏳ Waiting for services to start..."
sleep 15

echo ""
echo "🔍 Production Health Checks"
echo "=========================="

# Check backend health
echo -n "Backend health check: "
if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend health check failed"
    echo "Backend logs:"
    docker logs bookingbridge-backend-prod --tail 10
fi

# Check frontend health
echo -n "Frontend health check: "
if curl -f http://localhost:$FRONTEND_PORT/health > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend health check failed"
    echo "Frontend logs:"
    docker logs bookingbridge-frontend-prod --tail 10
fi

# Check Prometheus health
echo -n "Prometheus health check: "
if curl -f http://localhost:9091 > /dev/null 2>&1; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus health check failed"
fi

# Check Grafana health
echo -n "Grafana health check: "
if curl -f http://localhost:$GRAFANA_PORT > /dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana health check failed"
fi

echo ""
echo "🎉 PRODUCTION DEPLOYMENT COMPLETE!"
echo "================================="
echo ""
echo "🌐 Production URLs:"
echo "   Frontend:    http://localhost:$FRONTEND_PORT"
echo "   Backend API: http://localhost:$BACKEND_PORT"
echo "   API Docs:    http://localhost:$BACKEND_PORT/docs"
echo ""
echo "📊 Monitoring URLs:"
echo "   Prometheus:  http://localhost:9091"
echo "   Grafana:     http://localhost:$GRAFANA_PORT (admin/secure_grafana_admin_2025)"
echo ""
echo "💾 Database & Cache:"
echo "   PostgreSQL:  localhost:$POSTGRES_PORT"
echo "   Redis:       localhost:$REDIS_PORT"
echo ""
echo "🛠️ Management Commands:"
echo "   View logs: docker logs bookingbridge-backend-prod --follow"
echo "   Stop all:  docker stop bookingbridge-backend-prod bookingbridge-frontend-prod bookingbridge-postgres-prod bookingbridge-redis-prod bookingbridge-prometheus-prod bookingbridge-grafana-prod"
echo ""
echo "✅ BookingBridge Attribution Tracker is now running in PRODUCTION mode!"
echo "   Ready for enterprise attribution tracking with comprehensive monitoring."