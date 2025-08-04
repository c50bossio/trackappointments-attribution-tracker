# OAuth Setup Guide

## How to Get Real OAuth Credentials

To make the OAuth connections work with real provider accounts, you need to get OAuth credentials from each provider's developer portal.

## Environment File Location
📁 **File**: `/Users/bossio/6fb-booking/booking-attribution-tracker/backend/.env`

## Required OAuth Credentials

### 1. Square OAuth (for POS/Payment connections)
**Where to get**: https://developer.squareup.com/apps

1. Create a Square Developer Account
2. Create a new Application
3. Get your OAuth credentials:
   ```
   SQUARE_CLIENT_ID=your_actual_square_client_id
   SQUARE_CLIENT_SECRET=your_actual_square_client_secret
   ```

### 2. Facebook OAuth (for Facebook Ads connections)
**Where to get**: https://developers.facebook.com/apps

1. Create a Facebook App
2. Add "Facebook Login" product
3. Get your OAuth credentials:
   ```
   FACEBOOK_CLIENT_ID=your_actual_facebook_app_id
   FACEBOOK_CLIENT_SECRET=your_actual_facebook_app_secret
   ```

### 3. Google OAuth (for Google Ads connections)
**Where to get**: https://console.cloud.google.com/

1. Create a Google Cloud Project
2. Enable Google Ads API
3. Create OAuth 2.0 credentials
4. Get your OAuth credentials:
   ```
   GOOGLE_CLIENT_ID=your_actual_google_client_id
   GOOGLE_CLIENT_SECRET=your_actual_google_client_secret
   ```

### 4. Stripe OAuth (for Stripe Payments connections)
**Where to get**: https://dashboard.stripe.com/

1. Create a Stripe Account
2. Go to Connect settings
3. Get your OAuth credentials:
   ```
   STRIPE_CLIENT_ID=your_actual_stripe_client_id
   STRIPE_CLIENT_SECRET=your_actual_stripe_client_secret
   ```

## Current Status

✅ **OAuth System**: Fully functional and ready
⚠️ **Credentials**: Using demo values (causing connection errors)
🎯 **Next Step**: Replace demo credentials with real ones

## After Adding Real Credentials

1. **Restart the backend container**:
   ```bash
   docker stop trackappointments-backend-prod
   docker rm trackappointments-backend-prod
   docker run -d --name trackappointments-backend-prod -p 8002:8000 --env-file backend/.env trackappointments-backend:latest
   ```

2. **Test the connections**: Click "Connect with Square" and you'll be taken to Square's real login page!

## OAuth Flow (How it Works)

1. **User clicks "Connect with Square"**
2. **System generates OAuth URL**: `https://connect.squareup.com/oauth2/authorize?client_id=YOUR_REAL_ID&...`
3. **User redirects to Square**: Square login page opens
4. **User authorizes**: Logs in and approves access
5. **Square redirects back**: With authorization code
6. **System exchanges code**: For access token
7. **Connection complete**: Square account is now connected!

The OAuth integration is **production-ready** - it just needs real credentials instead of demo ones.