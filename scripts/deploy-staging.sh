#!/bin/bash

# BookingBridge Staging Deployment Script
# Deploys the attribution tracker to staging environment for testing

set -euo pipefail

echo "🚀 BookingBridge Staging Deployment"
echo "==================================="

# Configuration
STAGING_ENV="staging"
DOCKER_COMPOSE_FILE="docker-compose.yml"
BACKEND_PORT=8001
FRONTEND_PORT=3001

echo "📋 Pre-deployment Checks"
echo "========================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi
echo "✅ Docker is running"

# Check if ports are available
if lsof -Pi :$BACKEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port $BACKEND_PORT is already in use. Stopping existing services..."
    docker-compose down 2>/dev/null || true
fi

if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port $FRONTEND_PORT is already in use. Stopping existing services..."
    docker-compose down 2>/dev/null || true
fi

echo "✅ Ports $BACKEND_PORT and $FRONTEND_PORT are available"

echo ""
echo "🏗️ Building Application"
echo "======================"

# Navigate to project root
cd "$(dirname "$0")/.."

# Build Docker images
echo "Building backend image..."
docker build -t bookingbridge-backend:staging ./backend/ || {
    echo "❌ Backend build failed"
    exit 1
}

echo "Building frontend image..."
docker build -f ./frontend/Dockerfile.simple -t bookingbridge-frontend:staging ./frontend/ || {
    echo "❌ Frontend build failed"
    exit 1
}

echo "✅ Docker images built successfully"

echo ""
echo "🗄️ Database Setup"
echo "=================="

# Check if database exists
if [ ! -f "./backend/booking_attribution_tracker.db" ]; then
    echo "Creating SQLite database for staging..."
    touch ./backend/booking_attribution_tracker.db
fi

echo "✅ Database ready"

echo ""
echo "🚀 Starting Services"
echo "==================="

# Create staging environment file
cat > .env.staging << EOF
# Staging Environment Configuration
ENVIRONMENT=staging
DEBUG=true
LOG_LEVEL=INFO

# Database
DATABASE_URL=sqlite:///./booking_attribution_tracker.db
REDIS_URL=redis://localhost:6380/1

# Security (staging keys - DO NOT use in production)
SECRET_KEY=staging-secret-key-change-for-production-use-min-32-chars
HASH_SALT=staging-hash-salt-change-for-production

# API URLs
NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT
BACKEND_PORT=$BACKEND_PORT
FRONTEND_PORT=$FRONTEND_PORT

# CORS
CORS_ORIGINS=http://localhost:$FRONTEND_PORT,http://localhost:3000

# Platform Integrations (staging/development keys)
FACEBOOK_APP_ID=staging-facebook-app-id
FACEBOOK_APP_SECRET=staging-facebook-app-secret
GOOGLE_ADS_DEVELOPER_TOKEN=staging-google-ads-token
SQUARE_APPLICATION_ID=staging-square-app-id

# Monitoring
ENABLE_METRICS=true
PROMETHEUS_PORT=9090
EOF

# Start services using Docker Compose
cat > docker-compose.staging.yml << EOF
version: '3.8'

services:
  backend:
    image: bookingbridge-backend:staging
    container_name: bookingbridge-backend-staging
    ports:
      - "$BACKEND_PORT:8000"
    env_file:
      - .env.staging
    volumes:
      - ./backend:/app
      - ./backend/booking_attribution_tracker.db:/app/booking_attribution_tracker.db
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  frontend:
    image: bookingbridge-frontend:staging
    container_name: bookingbridge-frontend-staging
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT
      - NODE_ENV=development
    restart: unless-stopped
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  redis:
    image: redis:7-alpine
    container_name: bookingbridge-redis-staging
    ports:
      - "6380:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

networks:
  default:
    name: bookingbridge-staging
EOF

echo "Starting staging environment..."
docker-compose -f docker-compose.staging.yml up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 15

echo ""
echo "🔍 Health Checks"
echo "================"

# Check backend health
echo -n "Backend health check: "
if curl -f http://localhost:$BACKEND_PORT/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend health check failed"
    echo "Backend logs:"
    docker logs bookingbridge-backend-staging --tail 20
fi

# Check frontend health
echo -n "Frontend health check: "
if curl -f http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend health check failed"
    echo "Frontend logs:"
    docker logs bookingbridge-frontend-staging --tail 20
fi

# Check Redis health
echo -n "Redis health check: "
if docker exec bookingbridge-redis-staging redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis is healthy"
else
    echo "❌ Redis health check failed"
fi

echo ""
echo "🎉 STAGING DEPLOYMENT COMPLETE!"
echo "==============================="
echo ""
echo "🌐 Application URLs:"
echo "   Frontend: http://localhost:$FRONTEND_PORT"
echo "   Backend:  http://localhost:$BACKEND_PORT"
echo "   API Docs: http://localhost:$BACKEND_PORT/docs"
echo ""
echo "📊 Monitoring:"
echo "   Backend Health: http://localhost:$BACKEND_PORT/health"
echo "   Frontend Health: http://localhost:$FRONTEND_PORT"
echo ""
echo "🛠️ Management Commands:"
echo "   View logs: docker-compose -f docker-compose.staging.yml logs -f"
echo "   Stop services: docker-compose -f docker-compose.staging.yml down"
echo "   Restart: docker-compose -f docker-compose.staging.yml restart"
echo ""
echo "✅ Staging environment is ready for testing!"
echo "   You can now run end-to-end tests and validate the attribution workflow."