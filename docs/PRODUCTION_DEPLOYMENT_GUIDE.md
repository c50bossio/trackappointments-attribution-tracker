# BookingBridge Production Deployment Guide

## 📋 Overview

This guide provides comprehensive instructions for deploying BookingBridge Attribution Tracker to production environments. The platform is designed for enterprise-grade deployment with high availability, security, and scalability.

## 🏗️ Architecture Overview

### Production Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                     Load Balancer / CDN                     │
│                    (Nginx / Cloudflare)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Reverse Proxy                               │
│                  (Nginx Ingress)                           │
└─────────────┬───────────────────────────┬───────────────────┘
              │                           │
    ┌─────────▼──────────┐    ┌──────────▼─────────┐
    │    Frontend        │    │     Backend        │
    │   (Next.js)        │    │    (FastAPI)       │
    │ Replicas: 2-5      │    │  Replicas: 3-10    │
    └─────────┬──────────┘    └──────────┬─────────┘
              │                          │
              └──────────┬───────────────┘
                         │
        ┌────────────────▼─────────────────┐
        │            Services              │
        │  ┌──────────┐  ┌─────────────┐   │
        │  │PostgreSQL│  │    Redis    │   │
        │  │ Primary+ │  │   Cluster   │   │
        │  │ Replica  │  │             │   │
        │  └──────────┘  └─────────────┘   │
        └──────────────────────────────────┘
```

## 🚀 Quick Start Deployment

### Option 1: Automated Deployment Script

```bash
# 1. Clone and setup
git clone https://github.com/yourusername/booking-attribution-tracker.git
cd booking-attribution-tracker

# 2. Generate production secrets
./scripts/generate-production-secrets.sh

# 3. Configure environment variables
cp .env.production.template .env.production
# Edit .env.production with your actual values

# 4. Deploy to production
./scripts/deploy-production.sh
```

### Option 2: Manual Kubernetes Deployment

```bash
# 1. Build and push images
docker build -t your-registry/bookingbridge-backend:latest ./backend
docker build -t your-registry/bookingbridge-frontend:latest ./frontend
docker push your-registry/bookingbridge-backend:latest
docker push your-registry/bookingbridge-frontend:latest

# 2. Create namespace and secrets
kubectl create namespace bookingbridge
kubectl apply -f secrets/kubernetes-secrets.yaml

# 3. Deploy applications
kubectl apply -f k8s/ -n bookingbridge

# 4. Verify deployment
kubectl get pods -n bookingbridge
```

## 🔧 Prerequisites

### System Requirements

- **Kubernetes**: v1.24+ or Docker Compose v2.0+
- **Database**: PostgreSQL 13+ with 4GB+ RAM allocated
- **Cache**: Redis 6+ with 2GB+ RAM allocated
- **Storage**: 100GB+ SSD storage
- **Network**: SSL certificate for your domain
- **Monitoring**: Prometheus & Grafana (recommended)

### Required Tools

```bash
# Container tools
docker --version          # Docker 20.10+
kubectl version --client  # kubectl 1.24+

# Security tools
openssl version           # OpenSSL 1.1.1+
helm version             # Helm 3.0+ (optional)

# Monitoring tools
curl --version           # For health checks
jq --version            # For JSON processing
```

## 📝 Configuration

### 1. Environment Variables

Copy and configure the production environment:

```bash
cp .env.production.template .env.production
```

Key configurations to update:

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/bookingbridge_production

# External APIs
FACEBOOK_APP_SECRET=your_facebook_app_secret
GOOGLE_ADS_CLIENT_SECRET=your_google_ads_client_secret
SENDGRID_API_KEY=your_sendgrid_api_key

# Security
SECRET_KEY=generated_by_script
JWT_PRIVATE_KEY_PATH=/app/keys/jwt_private_key.pem

# Domain
APP_URL=https://yourdomain.com
NEXT_PUBLIC_API_URL=https://api.yourdomain.com
```

### 2. SSL Certificates

#### Option A: Let's Encrypt (Automatic)

```bash
# Using cert-manager in Kubernetes
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml

# Or using Certbot for manual setup
certbot certonly --nginx -d yourdomain.com -d api.yourdomain.com
```

#### Option B: Custom Certificates

```bash
# Place your certificates in the ssl directory
mkdir -p ssl/
cp your-domain.crt ssl/bookingbridge.crt
cp your-domain.key ssl/bookingbridge.key
cp your-ca-bundle.crt ssl/bookingbridge-chain.crt
```

### 3. Database Setup

#### PostgreSQL Configuration

```sql
-- Create production database and user
CREATE DATABASE bookingbridge_production;
CREATE USER bookingbridge_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE bookingbridge_production TO bookingbridge_user;

-- Enable required extensions
\c bookingbridge_production;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
```

#### Database Migrations

```bash
# Run migrations during deployment
kubectl run migration-job \
  --image=your-registry/bookingbridge-backend:latest \
  --restart=Never \
  --env="DATABASE_URL=$DATABASE_URL" \
  --command -- alembic upgrade head
```

## 🐳 Docker Compose Deployment

### Quick Production Setup

```bash
# 1. Build and start services
docker-compose -f docker-compose.production.yml up -d

# 2. Run migrations
docker-compose -f docker-compose.production.yml exec backend alembic upgrade head

# 3. Create admin user
docker-compose -f docker-compose.production.yml exec backend python create_admin_user.py

# 4. Verify deployment
docker-compose -f docker-compose.production.yml ps
```

### Services Overview

- **nginx**: Reverse proxy and SSL termination (ports 80, 443)
- **backend**: FastAPI application (3 replicas)
- **frontend**: Next.js application (2 replicas)
- **db**: PostgreSQL database with backups
- **redis**: Redis cache and session store
- **celery-worker**: Background task processing
- **celery-beat**: Scheduled task management
- **prometheus**: Metrics collection
- **grafana**: Monitoring dashboards

## ☸️ Kubernetes Deployment

### Cluster Setup

```bash
# 1. Create namespace
kubectl create namespace bookingbridge

# 2. Apply configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f secrets/kubernetes-secrets.yaml

# 3. Deploy services
kubectl apply -f k8s/database-deployment.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# 4. Verify deployment
kubectl get all -n bookingbridge
```

### Scaling Configuration

```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bookingbridge-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bookingbridge-backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🔐 Security Configuration

### 1. Network Security

```yaml
# Network Policy Example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: bookingbridge-network-policy
spec:
  podSelector:
    matchLabels:
      app: bookingbridge
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
```

### 2. Security Headers

Nginx is configured with comprehensive security headers:

- `Strict-Transport-Security`: HSTS enabled
- `X-Frame-Options`: Prevent clickjacking
- `X-Content-Type-Options`: Prevent MIME sniffing
- `Content-Security-Policy`: XSS protection
- `X-XSS-Protection`: Browser XSS filter

### 3. Rate Limiting

```nginx
# Rate limiting configuration
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
}

location /api/v1/auth/ {
    limit_req zone=auth_limit burst=10 nodelay;
}
```

## 📊 Monitoring & Observability

### 1. Health Checks

```bash
# Automated health checking
./scripts/health-check-production.sh --continuous

# JSON output for integration
./scripts/health-check-production.sh --json
```

### 2. Prometheus Metrics

Key metrics collected:

- **Application**: Request rate, response time, error rate
- **Database**: Connection pool, query performance
- **System**: CPU, memory, disk usage
- **Business**: Attribution matches, API calls, user activity

### 3. Grafana Dashboards

Pre-configured dashboards available:

- **Application Overview**: Key performance indicators
- **Infrastructure**: System resource usage
- **Business Metrics**: Attribution tracking performance
- **Error Tracking**: Error rates and patterns

### 4. Alerting Rules

```yaml
# Example Prometheus alert
groups:
- name: bookingbridge.rules
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"
```

## 🗄️ Database Management

### Backup Strategy

```bash
# Automated daily backups
0 2 * * * /usr/local/bin/backup-database.sh

# Manual backup
kubectl exec -n bookingbridge postgresql-0 -- \
  pg_dump -U bookingbridge_user bookingbridge_production > backup.sql
```

### Monitoring Database Performance

```sql
-- Check slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC LIMIT 10;

-- Check connection usage
SELECT count(*) as active_connections
FROM pg_stat_activity
WHERE state = 'active';
```

## 🚨 Disaster Recovery

### Backup Procedures

1. **Database Backups**: Automated daily backups to S3
2. **File Backups**: Application files and configurations
3. **Secret Backups**: Encrypted secret storage
4. **Infrastructure**: Terraform state backups

### Recovery Procedures

```bash
# 1. Restore database
kubectl exec -n bookingbridge postgresql-0 -- \
  psql -U bookingbridge_user bookingbridge_production < backup.sql

# 2. Restart application
kubectl rollout restart deployment/bookingbridge-backend -n bookingbridge

# 3. Verify recovery
./scripts/health-check-production.sh
```

## 🔄 CI/CD Pipeline

### GitHub Actions Integration

The deployment includes automated CI/CD pipelines:

1. **Staging Deployment**: Automatic on `staging` branch
2. **Production Deployment**: Automatic on `main` branch
3. **Security Scanning**: Trivy vulnerability scanning
4. **Testing**: Comprehensive test suite execution
5. **Rollback**: Automatic rollback on deployment failure

### Manual Deployment

```bash
# Deploy specific version
./scripts/deploy-production.sh --version v1.2.3

# Rollback deployment
./scripts/deploy-production.sh --rollback

# Dry run deployment
./scripts/deploy-production.sh --dry-run
```

## 🧪 Testing Production

### Load Testing

```bash
# Basic load test with curl
for i in {1..100}; do
  curl -s "https://yourdomain.com/api/health" > /dev/null &
done
wait

# Using Apache Bench
ab -n 1000 -c 10 https://yourdomain.com/api/health
```

### Integration Testing

```bash
# Run production integration tests
pytest tests/integration/ --url=https://yourdomain.com
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Database Connection Issues

```bash
# Check database connectivity
kubectl exec -n bookingbridge backend-pod -- \
  python -c "import asyncpg; print('DB accessible')"

# Check connection pool
kubectl logs -n bookingbridge deployment/bookingbridge-backend | grep "pool"
```

#### 2. SSL Certificate Issues

```bash
# Check certificate validity
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Verify certificate chain
curl -vI https://yourdomain.com
```

#### 3. Performance Issues

```bash
# Check resource usage
kubectl top pods -n bookingbridge

# Check application logs
kubectl logs -n bookingbridge deployment/bookingbridge-backend --tail=100
```

### Log Analysis

```bash
# Application logs
kubectl logs -n bookingbridge -l app=bookingbridge-backend -f

# Nginx access logs
kubectl logs -n bookingbridge -l app=nginx -f

# Database logs
kubectl logs -n bookingbridge -l app=postgresql -f
```

## 📈 Performance Optimization

### Database Optimization

```sql
-- Create indexes for attribution queries
CREATE INDEX CONCURRENTLY idx_interactions_timestamp 
ON interactions(created_at);

CREATE INDEX CONCURRENTLY idx_bookings_timestamp 
ON bookings(created_at);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM attribution_matches 
WHERE confidence > 0.7 AND created_at > NOW() - INTERVAL '24 hours';
```

### Application Optimization

```python
# Redis caching for frequent queries
@cached(ttl=300)  # 5 minutes
async def get_attribution_stats(business_id: int):
    return await fetch_attribution_stats(business_id)
```

### Nginx Optimization

```nginx
# Enable compression
gzip on;
gzip_types text/plain application/json;

# Enable caching
location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 1h;
    add_header Cache-Control "public, immutable";
}
```

## 🔧 Maintenance

### Regular Maintenance Tasks

```bash
# 1. Update dependencies
./scripts/update-dependencies.sh

# 2. Rotate secrets (quarterly)
./scripts/generate-production-secrets.sh --rotate

# 3. Database maintenance
kubectl exec postgresql-0 -- vacuumdb -U bookingbridge_user -d bookingbridge_production -z

# 4. Clean up old logs
kubectl exec backend-pod -- find /app/logs -name "*.log" -mtime +30 -delete
```

### Security Updates

```bash
# 1. Update base images
docker pull python:3.11-slim
docker pull node:18-alpine
docker pull postgres:15-alpine

# 2. Rebuild and deploy
./scripts/deploy-production.sh

# 3. Run security scan
./scripts/security-scan.sh
```

## 📞 Support & Contact

### Emergency Contacts

- **Platform Admin**: admin@yourdomain.com
- **DevOps Team**: devops@yourdomain.com
- **On-call Support**: +1-XXX-XXX-XXXX

### Documentation Links

- **API Documentation**: https://yourdomain.com/api/docs
- **Monitoring**: https://monitoring.yourdomain.com
- **Status Page**: https://status.yourdomain.com

### Getting Help

1. Check the [troubleshooting section](#troubleshooting)
2. Review application logs
3. Run health checks
4. Contact support team

---

## 📄 License

This deployment guide is part of the BookingBridge Attribution Tracker project.

## 🙏 Acknowledgments

Built with enterprise-grade tools and best practices:
- FastAPI for high-performance APIs
- Next.js for modern frontend
- PostgreSQL for reliable data storage
- Redis for caching and sessions
- Kubernetes for container orchestration
- Prometheus & Grafana for monitoring