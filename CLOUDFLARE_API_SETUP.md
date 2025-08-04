# Cloudflare API Token Setup

## Get Your API Token

1. **Go to**: https://dash.cloudflare.com/profile/api-tokens
2. **Click**: "Create Token"
3. **Select**: "Custom token"

## Token Permissions

Set these permissions:

### Permissions:
- **Zone** : **Zone Settings** : **Read**
- **Zone** : **DNS** : **Edit**

### Zone Resources:
- **Include** : **Specific zone** : **trackappointments.com**

### Client IP Address (Optional):
- Leave blank or add your current IP for extra security

## Token Usage

After creating the token, copy it and use one of these methods:

### Method 1: Export Environment Variable
```bash
export CLOUDFLARE_API_TOKEN="your_token_here"
```

### Method 2: Run Script with Token
```bash
CLOUDFLARE_API_TOKEN="your_token_here" ./scripts/add-dns-records.sh
```

### Method 3: Interactive Entry
Just run the script and enter the token when prompted:
```bash
./scripts/add-dns-records.sh
```

## What the Script Will Do

The script will automatically:
1. ✅ Find your Cloudflare zone ID
2. ✅ Add A record: trackappointments.com → Your Server IP
3. ✅ Add CNAME record: www.trackappointments.com → trackappointments.com
4. ✅ Add A record: api.trackappointments.com → Your Server IP
5. ✅ Add A record: staging.trackappointments.com → Your Server IP
6. ✅ Add A record: admin.trackappointments.com → Your Server IP
7. ✅ Enable SSL (Full mode)
8. ✅ Enable Always Use HTTPS
9. ✅ Enable HSTS security headers

## Required Information

You'll need to provide:
- **Cloudflare API Token** (from above)
- **Server IP Address** (where your app will run)
- **Staging IP** (can be same as main server)
- **Admin IP** (can be same as main server)

Ready to run: `./scripts/add-dns-records.sh`