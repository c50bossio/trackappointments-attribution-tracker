# Environment Variables Setup Guide

This guide will help you configure the environment variables in the `.env` file for the TrackAppointments Attribution Tracker.

## Quick Setup

1. **Copy the template**:
   ```bash
   cp backend/.env.template backend/.env
   ```

2. **Generate secure keys**:
   ```bash
   python -c "import secrets; print('SECRET_KEY=' + secrets.token_urlsafe(32))"
   python -c "import secrets; print('HASH_SALT=' + secrets.token_urlsafe(32))"
   ```

3. **Update the keys in your `.env` file** with the generated values.

## OAuth Provider Setup

### 1. Facebook OAuth (for Facebook Ads Integration)

1. Go to [Facebook Developers](https://developers.facebook.com/apps/)
2. Create a new app or use existing app
3. Add "Facebook Login" product
4. Set redirect URI: `http://localhost:8000/api/v1/oauth/callback` (development)
5. Get your App ID and App Secret:
   ```env
   FACEBOOK_CLIENT_ID=your_app_id_here
   FACEBOOK_CLIENT_SECRET=your_app_secret_here
   ```

### 2. Google OAuth (for Google Ads Integration)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google Ads API
4. Create OAuth 2.0 credentials
5. Add redirect URI: `http://localhost:8000/api/v1/oauth/callback`
6. Get your Client ID and Secret:
   ```env
   GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your_client_secret_here
   ```

### 3. Square OAuth (for Square Payments/Appointments)

1. Go to [Square Developer Dashboard](https://developer.squareup.com/apps)
2. Create a new application
3. Note your Application ID and Secret
4. Set redirect URI: `http://localhost:8000/api/v1/oauth/callback`
5. Configure:
   ```env
   SQUARE_CLIENT_ID=your_application_id_here
   SQUARE_CLIENT_SECRET=your_application_secret_here
   ```

### 4. Stripe OAuth (for Stripe Payments)

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/account/applications)
2. Create a new Connect application
3. Set redirect URI: `http://localhost:8000/api/v1/oauth/callback`
4. Get your Client ID and Secret:
   ```env
   STRIPE_CLIENT_ID=ca_your_client_id_here
   STRIPE_CLIENT_SECRET=sk_test_your_secret_key_here
   ```

## Database Configuration

### Development (SQLite)
Default configuration works out of the box:
```env
DATABASE_URL=sqlite:///./booking_attribution_tracker.db
```

### Production (PostgreSQL)
Update with your PostgreSQL connection string:
```env
DATABASE_URL=postgresql://username:password@host:port/database_name
```

For Render.com deployment, this is automatically provided.

## Security Configuration

### Generate Production Keys
```bash
# Generate SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Generate HASH_SALT  
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### JWT Keys
Generate RSA key pair for JWT tokens:
```bash
# Run the key generation script
./scripts/generate-production-secrets.sh
```

## Communication Services (Optional)

### SendGrid (Email notifications)
1. Create account at [SendGrid](https://sendgrid.com/)
2. Create API key
3. Configure:
   ```env
   SENDGRID_API_KEY=SG.your_api_key_here
   SENDGRID_FROM_EMAIL=noreply@yourdomain.com
   ```

### Twilio (SMS notifications)
1. Create account at [Twilio](https://www.twilio.com/)
2. Get Account SID and Auth Token
3. Configure:
   ```env
   TWILIO_ACCOUNT_SID=your_account_sid
   TWILIO_AUTH_TOKEN=your_auth_token
   ```

## Environment-Specific Configuration

### Development
```env
ENVIRONMENT=development
LOG_LEVEL=INFO
DATABASE_URL=sqlite:///./booking_attribution_tracker.db
CORS_ORIGINS=http://localhost:3000,http://localhost:3002
```

### Production
```env
ENVIRONMENT=production
LOG_LEVEL=WARNING
DATABASE_URL=postgresql://user:pass@host:port/db
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

## Verification Steps

1. **Test OAuth connections**:
   ```bash
   # Start the backend
   cd backend && uvicorn main:app --reload
   
   # Test OAuth endpoints
   curl http://localhost:8000/api/v1/oauth/providers
   ```

2. **Test database connection**:
   ```bash
   # Check health endpoint
   curl http://localhost:8000/health
   ```

3. **Test real data integration**:
   ```bash
   # After OAuth connections are established
   curl http://localhost:8000/api/v1/analytics/dashboard
   ```

## Common Issues

### OAuth Redirect URI Mismatch
- Ensure redirect URIs in provider settings match: `http://localhost:8000/api/v1/oauth/callback`
- For production: `https://yourdomain.com/api/v1/oauth/callback`

### Database Connection Issues
- Verify DATABASE_URL format
- Ensure database server is running
- Check credentials and permissions

### CORS Errors
- Add your frontend domain to CORS_ORIGINS
- Include both with and without www subdomain

## Security Checklist

- [ ] Generated secure SECRET_KEY and HASH_SALT
- [ ] Created JWT RSA key pair
- [ ] Set appropriate CORS_ORIGINS for production
- [ ] Enabled security headers and CSRF protection
- [ ] Used HTTPS in production
- [ ] Never commit actual secrets to version control

## Next Steps

After configuring your environment:

1. **Start the development server**:
   ```bash
   cd backend && uvicorn main:app --reload
   ```

2. **Test OAuth flows**:
   ```bash
   # Open in browser
   http://localhost:8000/docs
   ```

3. **Connect to platforms**: Use the OAuth endpoints to connect Facebook, Google, Square, and Stripe accounts

4. **Verify real data**: Check that dashboard shows real data from connected platforms