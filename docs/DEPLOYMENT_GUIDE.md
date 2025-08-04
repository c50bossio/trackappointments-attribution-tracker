# BookingBridge Production Deployment Guide

This comprehensive guide covers the complete production deployment process for the BookingBridge Attribution Tracker platform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Environment Configuration](#environment-configuration)
4. [Deployment Methods](#deployment-methods)
5. [Security Configuration](#security-configuration)
6. [Monitoring Setup](#monitoring-setup)
7. [Database Management](#database-management)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance Procedures](#maintenance-procedures)

## Prerequisites

### System Requirements

**Minimum Production Requirements:**
- **CPU**: 8 cores
- **Memory**: 16GB RAM
- **Storage**: 200GB SSD
- **Network**: 1Gbps connection

**Recommended Production Requirements:**
- **CPU**: 16 cores
- **Memory**: 32GB RAM
- **Storage**: 500GB NVMe SSD
- **Network**: 10Gbps connection

### Software Dependencies

**Required Software:**
- Docker 24.0+
- Docker Compose 2.20+
- Kubernetes 1.28+ (for K8s deployment)
- kubectl 1.28+
- Helm 3.12+ (optional)
- PostgreSQL 15+ (external or containerized)
- Redis 7+ (external or containerized)

**Optional Tools:**
- AWS CLI 2.13+ (for S3 backups)
- Terraform 1.5+ (for infrastructure as code)
- Ansible 8.0+ (for configuration management)

### External Services

**Required API Keys:**
- Facebook App ID and Secret
- Google Ads API credentials
- SendGrid API key
- Twilio credentials (optional)
- Sentry DSN (recommended)

**Infrastructure Services:**
- SSL certificates (Let's Encrypt or commercial)
- Domain name with DNS control
- S3-compatible storage for backups
- SMTP service for notifications

## Infrastructure Setup

### Option 1: Docker Compose Deployment

**Best for:** Small to medium deployments, development staging

```bash
# 1. Clone repository
git clone https://github.com/your-org/booking-attribution-tracker.git
cd booking-attribution-tracker

# 2. Generate production secrets
./scripts/generate-secrets.sh --all

# 3. Configure environment
cp .env.production.template .env.production
# Edit .env.production with your values

# 4. Start production stack
docker-compose -f docker-compose.production.yml up -d

# 5. Verify deployment
curl https://your-domain.com/api/health
```

### Option 2: Kubernetes Deployment

**Best for:** Large deployments, high availability, auto-scaling

```bash
# 1. Prepare Kubernetes cluster
kubectl create namespace bookingbridge

# 2. Generate and apply secrets
./scripts/generate-secrets.sh --k8s-secrets production
kubectl apply -f k8s/secrets-generated.yaml

# 3. Deploy infrastructure components
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/database-deployment.yaml

# 4. Deploy application
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# 5. Verify deployment
kubectl get pods -n bookingbridge
kubectl get services -n bookingbridge
```

### Option 3: Cloud Provider Deployment

#### AWS ECS/Fargate

```bash
# 1. Create ECS cluster
aws ecs create-cluster --cluster-name bookingbridge-prod

# 2. Create task definitions
aws ecs register-task-definition --cli-input-json file://aws/ecs-task-definition.json

# 3. Create services
aws ecs create-service --cluster bookingbridge-prod --service-name bookingbridge-backend --task-definition bookingbridge-backend:1

# 4. Set up Application Load Balancer
aws elbv2 create-load-balancer --name bookingbridge-alb --subnets subnet-12345 subnet-67890
```

#### Google Cloud Run

```bash
# 1. Build and push images
gcloud builds submit --tag gcr.io/PROJECT_ID/bookingbridge-backend backend/
gcloud builds submit --tag gcr.io/PROJECT_ID/bookingbridge-frontend frontend/

# 2. Deploy services
gcloud run deploy bookingbridge-backend --image gcr.io/PROJECT_ID/bookingbridge-backend --platform managed
gcloud run deploy bookingbridge-frontend --image gcr.io/PROJECT_ID/bookingbridge-frontend --platform managed
```

## Environment Configuration

### Production Environment Variables

Create and configure `.env.production`:

```bash
# Required Configuration
ENVIRONMENT=production
DATABASE_URL=postgresql://user:password@db:5432/bookingbridge
REDIS_URL=redis://:password@redis:6379/0
SECRET_KEY=your-super-secure-secret-key
JWT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----..."
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----..."

# External APIs
FACEBOOK_APP_ID=your-facebook-app-id
FACEBOOK_APP_SECRET=your-facebook-app-secret
GOOGLE_ADS_CLIENT_ID=your-google-ads-client-id
GOOGLE_ADS_CLIENT_SECRET=your-google-ads-client-secret

# Domain Configuration
CORS_ORIGINS=https://bookingbridge.com,https://www.bookingbridge.com
FRONTEND_URL=https://bookingbridge.com
BACKEND_URL=https://bookingbridge.com/api

# Monitoring
SENTRY_DSN=your-sentry-dsn
ENABLE_METRICS=true
```

### Secrets Management

**For Docker Compose:**
```bash
# Use Docker secrets
echo "your-database-password" | docker secret create db-password -
echo "your-redis-password" | docker secret create redis-password -
```

**For Kubernetes:**
```bash
# Create secrets
kubectl create secret generic bookingbridge-secrets \
  --from-literal=DATABASE_URL="postgresql://..." \
  --from-literal=REDIS_URL="redis://..." \
  --from-literal=SECRET_KEY="..." \
  -n bookingbridge
```

**For Production Security:**
- Use HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

## Deployment Methods

### Blue-Green Deployment

```bash
# 1. Deploy new version to "green" environment
docker-compose -f docker-compose.green.yml up -d

# 2. Run health checks
./scripts/health-check.sh green

# 3. Switch traffic (update load balancer)
# Update nginx configuration or cloud load balancer

# 4. Monitor for issues
./scripts/monitor-deployment.sh

# 5. If successful, tear down blue environment
docker-compose -f docker-compose.blue.yml down
```

### Rolling Deployment (Kubernetes)

```bash
# 1. Update image tags in deployment manifests
kubectl set image deployment/bookingbridge-backend \
  backend=bookingbridge/backend:v1.2.0 -n bookingbridge

# 2. Monitor rollout
kubectl rollout status deployment/bookingbridge-backend -n bookingbridge

# 3. Rollback if needed
kubectl rollout undo deployment/bookingbridge-backend -n bookingbridge
```

### Canary Deployment

```bash
# 1. Deploy canary version (10% traffic)
kubectl apply -f k8s/canary-deployment.yaml

# 2. Monitor metrics
# Check error rates, response times, user feedback

# 3. Gradually increase traffic
kubectl scale deployment bookingbridge-backend-canary --replicas=3

# 4. Full rollout or rollback based on metrics
```

## Security Configuration

### SSL/TLS Setup

**Let's Encrypt (Recommended):**
```bash
# 1. Install certbot
sudo apt-get install certbot

# 2. Obtain certificates
sudo certbot certonly --standalone -d bookingbridge.com -d www.bookingbridge.com

# 3. Configure auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

**Commercial Certificate:**
```bash
# 1. Generate CSR
openssl req -new -newkey rsa:4096 -nodes \
  -keyout bookingbridge.com.key \
  -out bookingbridge.com.csr

# 2. Submit CSR to CA and download certificate
# 3. Install certificate in nginx/load balancer
```

### Firewall Configuration

```bash
# Ubuntu/Debian with ufw
sudo ufw enable
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw deny 8000/tcp  # Block direct backend access
sudo ufw deny 5432/tcp  # Block direct database access

# Rate limiting with fail2ban
sudo apt-get install fail2ban
sudo cp security/fail2ban/bookingbridge.conf /etc/fail2ban/jail.d/
sudo systemctl restart fail2ban
```

### Security Headers

Configure in nginx or cloud load balancer:

```nginx
# Security headers (already included in nginx-security.conf)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Content-Security-Policy "default-src 'self'; ..." always;
```

## Monitoring Setup

### Prometheus and Grafana

```bash
# 1. Deploy monitoring stack
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# 2. Configure Prometheus targets
# Edit monitoring/prometheus/prometheus.yml

# 3. Import Grafana dashboards
# Navigate to http://localhost:3001
# Import dashboards from monitoring/grafana/dashboards/

# 4. Set up alerting
# Edit monitoring/alertmanager/config.yml
# Configure Slack/email notifications
```

### Application Metrics

**Backend Metrics:**
- Request rate and response time
- Error rates by endpoint
- Database connection pool status
- Attribution matching rates
- External API response times

**Frontend Metrics:**
- Page load times
- JavaScript errors
- User engagement metrics
- Conversion funnel metrics

**Infrastructure Metrics:**
- CPU and memory usage
- Disk I/O and space
- Network throughput
- Container restarts

### Log Aggregation

```bash
# 1. Configure log shipping
# Use promtail, fluent-bit, or filebeat

# 2. Set up log storage
# Options: Loki, Elasticsearch, CloudWatch

# 3. Create log dashboards
# Configure log queries and alerts
```

## Database Management

### Initial Setup

```bash
# 1. Create production database
createdb -h localhost -U postgres bookingbridge

# 2. Run migrations
cd backend
alembic upgrade head

# 3. Create database users
psql -h localhost -U postgres -d bookingbridge -c "
  CREATE USER bookingbridge_app WITH PASSWORD 'secure-password';
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bookingbridge_app;
  GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO bookingbridge_app;
"

# 4. Configure connection pooling
# Use PgBouncer or built-in pooling
```

### Backup Configuration

```bash
# 1. Set up automated backups
./database/backup/backup-database.sh

# 2. Configure backup schedule
crontab -e
# Add: 0 2 * * * /opt/bookingbridge/database/backup/backup-database.sh

# 3. Test backup restoration
./database/recovery/disaster-recovery.sh --test-restore /path/to/backup.sql.gz

# 4. Set up S3 backup sync
aws s3 sync /opt/bookingbridge/backups/ s3://bookingbridge-backups/
```

### Performance Tuning

**PostgreSQL Configuration:**
```sql
-- postgresql.conf optimizations
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 256MB
maintenance_work_mem = 1GB
max_connections = 200
checkpoint_completion_target = 0.9
wal_buffers = 32MB
```

**Monitoring Queries:**
```sql
-- Slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Connection usage
SELECT count(*), state
FROM pg_stat_activity
GROUP BY state;

-- Database size
SELECT pg_size_pretty(pg_database_size('bookingbridge'));
```

## Troubleshooting

### Common Issues

**1. High CPU Usage**
```bash
# Check container stats
docker stats

# Check processes
top -p $(docker inspect --format '{{.State.Pid}}' bookingbridge-backend)

# Scale horizontally
kubectl scale deployment bookingbridge-backend --replicas=5
```

**2. Database Connection Issues**
```bash
# Check database connectivity
pg_isready -h db-host -p 5432 -U postgres

# Check connection pool
docker logs bookingbridge-backend | grep "connection pool"

# Check database locks
SELECT * FROM pg_locks WHERE NOT granted;
```

**3. High Memory Usage**
```bash
# Check memory usage
docker exec bookingbridge-backend ps aux --sort=-%mem

# Check for memory leaks
docker exec bookingbridge-backend cat /proc/meminfo

# Restart containers if needed
docker-compose restart bookingbridge-backend
```

**4. SSL Certificate Issues**
```bash
# Check certificate validity
openssl x509 -in /path/to/cert.pem -text -noout

# Test SSL configuration
curl -I https://bookingbridge.com

# Renew Let's Encrypt certificates
certbot renew --dry-run
```

### Debug Commands

```bash
# Check all services
docker-compose ps
kubectl get pods -n bookingbridge

# View logs
docker-compose logs --follow bookingbridge-backend
kubectl logs -f deployment/bookingbridge-backend -n bookingbridge

# Execute commands in containers
docker exec -it bookingbridge-backend bash
kubectl exec -it deployment/bookingbridge-backend -- bash

# Check network connectivity
docker exec bookingbridge-backend ping bookingbridge-postgresql
kubectl exec deployment/bookingbridge-backend -- nslookup bookingbridge-postgresql
```

## Maintenance Procedures

### Regular Maintenance Tasks

**Daily:**
- Check application health
- Review error logs
- Monitor resource usage
- Verify backup completion

**Weekly:**
- Update security patches
- Review performance metrics
- Clean up old logs
- Test disaster recovery procedures

**Monthly:**
- Security audit
- Dependency updates
- Database maintenance
- Cost optimization review

### Update Procedures

**Security Updates:**
```bash
# 1. Review security advisories
# 2. Test updates in staging
# 3. Schedule maintenance window
# 4. Apply updates with rollback plan
# 5. Verify security posture
```

**Application Updates:**
```bash
# 1. Deploy to staging environment
# 2. Run automated tests
# 3. Perform manual QA
# 4. Deploy to production using blue-green strategy
# 5. Monitor metrics and logs
```

### Disaster Recovery

**Database Disaster:**
```bash
# 1. Assess the situation
./database/recovery/disaster-recovery.sh --assess

# 2. Restore from latest backup
./database/recovery/disaster-recovery.sh --restore-latest

# 3. Verify data integrity
./database/recovery/disaster-recovery.sh --verify-backups

# 4. Resume operations
# 5. Conduct post-incident review
```

**Complete System Disaster:**
```bash
# 1. Set up new infrastructure
# 2. Restore from backups
# 3. Redirect DNS
# 4. Verify all services
# 5. Communicate with stakeholders
```

### Performance Optimization

**Database Optimization:**
```sql
-- Analyze table statistics
ANALYZE;

-- Reindex tables
REINDEX DATABASE bookingbridge;

-- Update query planner statistics
UPDATE pg_stat_user_tables SET n_tup_ins = 0, n_tup_upd = 0, n_tup_del = 0;
```

**Application Optimization:**
```bash
# Profile application performance
docker exec bookingbridge-backend python -m cProfile -o profile.stats main.py

# Optimize container resources
docker update --memory=2g --cpus=2 bookingbridge-backend

# Scale based on metrics
kubectl autoscale deployment bookingbridge-backend \
  --cpu-percent=70 --min=3 --max=10
```

### Cost Optimization

**Resource Optimization:**
- Right-size containers based on actual usage
- Use spot instances for non-critical workloads
- Implement auto-scaling for dynamic workloads
- Archive old data to cold storage

**Monitoring Costs:**
- Set up billing alerts
- Track resource utilization
- Review and optimize regularly
- Use reserved instances for steady workloads

## Support and Escalation

### Support Contacts

**Level 1 Support:**
- Application monitoring alerts
- Basic troubleshooting
- Log analysis

**Level 2 Support:**
- Performance issues
- Database problems
- Security incidents

**Level 3 Support:**
- Architecture changes
- Disaster recovery
- Major incidents

### Escalation Procedures

1. **Incident Detection**: Monitoring alerts or user reports
2. **Initial Response**: Acknowledge incident, assess severity
3. **Investigation**: Gather logs, reproduce issue
4. **Resolution**: Implement fix, test, deploy
5. **Post-Incident**: Document lessons learned, improve processes

### Emergency Contacts

```yaml
Primary On-Call: +1-555-0100
Secondary On-Call: +1-555-0101
Database DBA: +1-555-0102
Security Team: +1-555-0103
Management: +1-555-0104
```

---

## Quick Reference

### Essential Commands

```bash
# Health checks
curl https://bookingbridge.com/api/health
docker-compose ps
kubectl get all -n bookingbridge

# Logs
docker-compose logs --follow
kubectl logs -f deployment/bookingbridge-backend

# Backups
./database/backup/backup-database.sh
./database/recovery/disaster-recovery.sh --list-backups

# Security
./security/scripts/security-scan.sh
nmap -sS -A bookingbridge.com

# Monitoring
curl http://localhost:9090/api/v1/query?query=up
curl http://localhost:3001/api/health
```

### Emergency Procedures

1. **Service Down**: Check logs, restart services, scale if needed
2. **Database Issues**: Check connections, review slow queries, consider failover
3. **Security Breach**: Isolate systems, change passwords, notify stakeholders
4. **Performance Issues**: Check resources, scale horizontally, optimize queries

For additional support, consult the [troubleshooting runbook](TROUBLESHOOTING_RUNBOOK.md) or contact the on-call engineer.