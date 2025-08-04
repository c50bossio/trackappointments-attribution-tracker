# BookingBridge Domain Purchase Guide

## Selected Domain: bookingbridge.app

### Step 1: Purchase Domain at Cloudflare
1. Go to: https://dash.cloudflare.com/
2. Click "Register Domain"  
3. Search for: `bookingbridge.app`
4. Complete purchase (~$19/year for .app domains)

### Step 2: Automatic Configuration
Once purchased, the domain will automatically get:
- ✅ Free SSL certificates
- ✅ WHOIS privacy protection  
- ✅ DDoS protection
- ✅ DNS management

### Step 3: DNS Configuration
Add these DNS records in Cloudflare dashboard:

```
A     @       [YOUR-SERVER-IP]     🟠 Proxied
CNAME www     bookingbridge.app   🟠 Proxied  
A     api     [YOUR-API-IP]        🟠 Proxied
A     staging [YOUR-STAGING-IP]    🟠 Proxied
A     admin   [YOUR-ADMIN-IP]      🟠 Proxied
```

### Step 4: SSL & Security (Auto-applied)
- SSL Mode: Full (strict)
- Always Use HTTPS: ✅ On
- HSTS: ✅ Enabled
- Bot Protection: ✅ Enabled
- WAF: ✅ Enabled

### Step 5: Deploy Production
```bash
./deploy-production-simple.sh
```

## Final URLs:
- **Main App**: https://bookingbridge.app
- **API**: https://api.bookingbridge.app  
- **Staging**: https://staging.bookingbridge.app
- **Admin**: https://admin.bookingbridge.app

## Total Cost: ~$19/year
- Domain: $19/year (.app TLD)
- SSL: $0 (included)
- DNS: $0 (included)
- Security: $0 (included)

🚀 **Your BookingBridge platform will be live at: https://bookingbridge.app**
