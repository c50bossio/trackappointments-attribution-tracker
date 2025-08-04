# TrackAppointments.com DNS Setup Guide

## 🌐 Domain: trackappointments.com (Your Existing Domain)

### Step 1: Add DNS Records
Add these DNS records in your domain provider's control panel:

#### A Records (Point to your server IP)
```
Type: A     Name: @         Value: [YOUR-PRODUCTION-IP]    TTL: 300
Type: A     Name: api       Value: [YOUR-API-SERVER-IP]    TTL: 300  
Type: A     Name: staging   Value: [YOUR-STAGING-IP]       TTL: 300
Type: A     Name: admin     Value: [YOUR-ADMIN-IP]         TTL: 300
```

#### CNAME Record (WWW redirect)
```
Type: CNAME Name: www       Value: trackappointments.com   TTL: 300
```

### Step 2: SSL Certificate Setup

#### Option A: Cloudflare (Recommended)
1. Transfer DNS to Cloudflare (keeps domain registration with current provider)
2. Automatic SSL certificates
3. Built-in CDN and DDoS protection
4. Free tier available

#### Option B: Let's Encrypt (Free)
1. Install certbot on your server
2. Generate certificates for all subdomains:
   ```bash
   certbot --nginx -d trackappointments.com -d www.trackappointments.com -d api.trackappointments.com -d staging.trackappointments.com -d admin.trackappointments.com
   ```

#### Option C: Paid SSL Certificate
1. Purchase wildcard SSL certificate
2. Install on your web server/load balancer

### Step 3: Server Configuration

#### Nginx Configuration Example:
```nginx
# /etc/nginx/sites-available/trackappointments.com
server {
    listen 80;
    server_name trackappointments.com www.trackappointments.com;
    return 301 https://trackappointments.com$request_uri;
}

server {
    listen 443 ssl http2;
    server_name trackappointments.com www.trackappointments.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl http2;
    server_name api.trackappointments.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 4: Deploy Application
```bash
./scripts/deploy-trackappointments.sh
```

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
