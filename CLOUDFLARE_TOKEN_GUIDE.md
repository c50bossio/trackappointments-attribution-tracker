# 🔑 Cloudflare API Token Setup Guide

## Step-by-Step Instructions

### 1. Go to API Tokens Page
Open: https://dash.cloudflare.com/profile/api-tokens

### 2. Create New Token
Click the **"Create Token"** button

### 3. Choose Template
Select **"Custom token"** (not one of the pre-made templates)

### 4. Set Token Name
Enter: `TrackAppointments DNS Editor`

### 5. Configure Permissions (CRITICAL STEP)
Add these two permissions exactly:

**Permission 1:**
- Resource: `Zone`
- Permission: `Zone Settings`  
- Access: `Read`

**Permission 2:** (This is the one that was missing!)
- Resource: `Zone`
- Permission: `DNS`
- Access: `Edit`

### 6. Configure Zone Resources
Add this resource:

**Zone Resources:**
- Action: `Include`
- Resource: `Specific zone`
- Zone: `trackappointments.com`

### 7. Client IP (Optional)
Leave blank (or add your current IP for extra security)

### 8. TTL (Optional)  
Leave as default or set expiration date

### 9. Create Token
1. Click **"Continue to summary"**
2. Review the settings
3. Click **"Create Token"**

### 10. Copy Token
**IMPORTANT:** Copy the token immediately - you won't see it again!

The token will look like: `abc123def456ghi789...`

## ✅ Verification
Your token should show these permissions in the summary:
```
Zone:Zone Settings:Read - trackappointments.com
Zone:DNS:Edit - trackappointments.com
```

## 🚀 Use the Token
Once you have the token, run:
```bash
./auto-dns-setup.sh
```

When prompted, paste the token you just created.

## 🔧 Common Issues

**"Authentication error"** = Wrong permissions (missing DNS Edit)
**"Zone not found"** = Wrong zone in resources
**"Access denied"** = Token expired or revoked

## ✅ Success Indicators
When it works, you'll see:
```
✅ Success (for each DNS record)
✅ SSL configured (Full mode)
✅ Always HTTPS enabled
```