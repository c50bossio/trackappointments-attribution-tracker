# TrackAppointments Production Monitoring

## 🔍 Health Check Script

### Usage
```bash
# Run health check
node monitoring/health-check.js

# Run with cron for monitoring
# Add to crontab: */5 * * * * /usr/bin/node /path/to/monitoring/health-check.js
```

### Monitored Endpoints
- **Frontend**: https://trackappointments.com
- **API Health**: https://api.trackappointments.com/health  
- **OAuth Providers**: https://api.trackappointments.com/api/v1/oauth/providers

### Response Time Thresholds
- 🟢 **Good**: < 1000ms
- 🟡 **Warning**: 1000-3000ms  
- 🔴 **Critical**: > 3000ms

### Exit Codes
- `0`: All services healthy
- `1`: One or more services unhealthy

## 📊 Monitoring Setup Options

### Option 1: Simple Cron Monitoring
```bash
# Check every 5 minutes
*/5 * * * * /usr/bin/node /path/to/monitoring/health-check.js >> /var/log/trackappointments-health.log 2>&1
```

### Option 2: External Monitoring Services
Recommended external monitoring services:

- **UptimeRobot** (Free tier available)
  - Monitor: https://trackappointments.com
  - Monitor: https://api.trackappointments.com/health

- **Pingdom** (Paid service)
  - Full website monitoring
  - Performance insights

- **StatusCake** (Free tier available)  
  - Basic uptime monitoring
  - Email alerts

### Option 3: Render Native Monitoring
Render provides built-in monitoring:
- Service health checks
- Resource usage metrics
- Deployment notifications

## 🚨 Alert Configuration

### Key Metrics to Alert On
- **Response Time** > 3 seconds
- **Error Rate** > 5%
- **Service Downtime** > 1 minute
- **SSL Certificate** expiration < 30 days

### Recommended Alert Channels
- Email notifications
- Slack/Discord webhooks
- SMS for critical alerts

## 📈 Performance Baselines

### Current Performance (2025-08-05)
- **Frontend**: ~300ms average response time
- **API Health**: ~500ms average response time
- **OAuth Endpoints**: ~400ms average response time

### Performance Targets
- **Frontend**: < 1000ms (95th percentile)
- **API**: < 2000ms (95th percentile)
- **Uptime**: > 99.5% monthly

## 🔧 Troubleshooting

### Common Issues
1. **High Response Times**
   - Check Render service metrics
   - Monitor database performance
   - Review Cloudflare analytics

2. **SSL Certificate Issues**
   - Verify domain ownership in Render
   - Check DNS propagation
   - Contact Render support if needed

3. **OAuth Endpoint Failures**
   - Verify OAuth provider credentials
   - Check callback URL configurations
   - Review API rate limits

### Health Check Failures
If health checks fail:
1. Check service logs in Render dashboard
2. Verify DNS resolution
3. Test endpoints manually with curl
4. Check for recent deployments or changes