"""
OAuth Integration Endpoints
Handles OAuth flows for Facebook, Google, Square, and Stripe
"""

from fastapi import APIRouter, HTTPException, Request, status, Query
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
import logging
import os
import uuid
import time
from datetime import datetime, timedelta
import base64
import hashlib
import json

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/oauth", tags=["OAuth Integrations"])

# OAuth state storage (in production, use Redis or database)
oauth_states = {}

class OAuthConnectRequest(BaseModel):
    provider: str  # facebook, google, square, stripe
    business_id: str
    redirect_url: Optional[str] = None

class OAuthCallbackData(BaseModel):
    provider: str
    code: str
    state: str
    business_id: str

# OAuth provider configurations
OAUTH_CONFIGS = {
    "facebook": {
        "client_id": os.getenv("FACEBOOK_APP_ID", "demo-facebook-app-id"),
        "client_secret": os.getenv("FACEBOOK_APP_SECRET", "demo-facebook-secret"),
        "auth_url": "https://www.facebook.com/v18.0/dialog/oauth",
        "token_url": "https://graph.facebook.com/v18.0/oauth/access_token",
        "scopes": ["ads_management", "ads_read", "read_insights"],
        "name": "Facebook Ads"
    },
    "google": {
        "client_id": os.getenv("GOOGLE_CLIENT_ID", "demo-google-client-id"),
        "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", "demo-google-secret"),
        "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
        "token_url": "https://oauth2.googleapis.com/token",
        "scopes": ["https://www.googleapis.com/auth/adwords", "https://www.googleapis.com/auth/analytics.readonly"],
        "name": "Google Ads"
    },
    "square": {
        "client_id": os.getenv("SQUARE_CLIENT_ID", "demo-square-client-id"),
        "client_secret": os.getenv("SQUARE_CLIENT_SECRET", "demo-square-secret"),
        "auth_url": "https://connect.squareup.com/oauth2/authorize",
        "token_url": "https://connect.squareup.com/oauth2/token",
        "scopes": ["PAYMENTS_READ", "ORDERS_READ", "CUSTOMERS_READ"],
        "name": "Square Payments"
    },
    "stripe": {
        "client_id": os.getenv("STRIPE_CLIENT_ID", "demo-stripe-client-id"),
        "client_secret": os.getenv("STRIPE_CLIENT_SECRET", "demo-stripe-secret"),
        "auth_url": "https://connect.stripe.com/oauth/authorize",
        "token_url": "https://connect.stripe.com/oauth/token",
        "scopes": ["read_only"],
        "name": "Stripe Payments"
    }
}

def generate_oauth_state(provider: str, business_id: str) -> str:
    """Generate secure OAuth state parameter"""
    state_data = {
        "provider": provider,
        "business_id": business_id,
        "timestamp": time.time(),
        "nonce": str(uuid.uuid4())
    }
    
    state_string = base64.b64encode(json.dumps(state_data).encode()).decode()
    
    # Store for validation (expire after 10 minutes)
    oauth_states[state_string] = {
        "data": state_data,
        "expires_at": time.time() + 600
    }
    
    return state_string

def validate_oauth_state(state: str) -> Optional[Dict[str, Any]]:
    """Validate OAuth state parameter"""
    if state not in oauth_states:
        return None
    
    state_info = oauth_states[state]
    
    # Check if expired
    if time.time() > state_info["expires_at"]:
        oauth_states.pop(state, None)
        return None
    
    return state_info["data"]

@router.post("/connect")
async def initiate_oauth_connection(request: OAuthConnectRequest):
    """Initiate OAuth connection flow"""
    try:
        provider = request.provider.lower()
        
        if provider not in OAUTH_CONFIGS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported provider: {provider}"
            )
        
        config = OAUTH_CONFIGS[provider]
        
        # Generate secure state parameter
        state = generate_oauth_state(provider, request.business_id)
        
        # Build OAuth authorization URL
        redirect_uri = request.redirect_url or f"http://localhost:3002/oauth/callback"
        
        auth_params = {
            "client_id": config["client_id"],
            "redirect_uri": redirect_uri,
            "state": state,
            "response_type": "code",
            "scope": " ".join(config["scopes"])
        }
        
        # Provider-specific parameters
        if provider == "facebook":
            auth_params["display"] = "popup"
        elif provider == "google":
            auth_params["access_type"] = "offline"
            auth_params["prompt"] = "consent"
        elif provider == "stripe":
            auth_params["stripe_landing"] = "login"
        
        # Build URL
        auth_url = config["auth_url"] + "?" + "&".join([f"{k}={v}" for k, v in auth_params.items()])
        
        logger.info(f"OAuth connection initiated for {provider} by business {request.business_id}")
        
        return {
            "provider": provider,
            "provider_name": config["name"],
            "authorization_url": auth_url,
            "state": state,
            "expires_in": 600,  # 10 minutes
            "instructions": f"Redirect user to authorization_url to complete {config['name']} connection"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error initiating OAuth connection: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to initiate OAuth connection"
        )

@router.get("/callback")
async def oauth_callback(
    code: str = Query(..., description="Authorization code from provider"),
    state: str = Query(..., description="OAuth state parameter"),
    error: Optional[str] = Query(None, description="OAuth error if any")
):
    """Handle OAuth callback"""
    try:
        # Handle OAuth errors
        if error:
            logger.warning(f"OAuth error received: {error}")
            return RedirectResponse(
                url=f"http://localhost:3002/dashboard?oauth_error={error}",
                status_code=302
            )
        
        # Validate state
        state_data = validate_oauth_state(state)
        if not state_data:
            logger.warning(f"Invalid or expired OAuth state: {state}")
            return RedirectResponse(
                url="http://localhost:3002/dashboard?oauth_error=invalid_state",
                status_code=302
            )
        
        provider = state_data["provider"]
        business_id = state_data["business_id"]
        
        if provider not in OAUTH_CONFIGS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid provider: {provider}"
            )
        
        # In a real implementation, you would:
        # 1. Exchange authorization code for access token
        # 2. Store encrypted tokens in database
        # 3. Test API connectivity
        # 4. Set up webhooks if needed
        
        # For demo purposes, simulate successful connection
        connection_id = f"conn-{provider}-{int(time.time())}"
        
        # Simulate token exchange (normally you'd make HTTP request to provider)
        logger.info(f"Simulating token exchange for {provider} with code: {code[:20]}...")
        
        # Clean up state
        oauth_states.pop(state, None)
        
        # Store connection info (in production, use database)
        connection_info = {
            "connection_id": connection_id,
            "provider": provider,
            "business_id": business_id,
            "status": "connected",
            "connected_at": datetime.utcnow().isoformat(),
            "account_name": f"Demo {OAUTH_CONFIGS[provider]['name']} Account",
            "permissions": OAUTH_CONFIGS[provider]["scopes"]
        }
        
        logger.info(f"OAuth connection successful: {provider} for business {business_id}")
        
        # Redirect back to dashboard with success
        return RedirectResponse(
            url=f"http://localhost:3002/dashboard?oauth_success={provider}&connection_id={connection_id}",
            status_code=302
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing OAuth callback: {str(e)}")
        return RedirectResponse(
            url="http://localhost:3002/dashboard?oauth_error=callback_failed",
            status_code=302
        )

@router.post("/disconnect")
async def disconnect_oauth_provider(provider: str, business_id: str):
    """Disconnect OAuth provider"""
    try:
        if provider not in OAUTH_CONFIGS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported provider: {provider}"
            )
        
        # In production, you would:
        # 1. Revoke access tokens
        # 2. Remove stored credentials
        # 3. Disable webhooks
        # 4. Update connection status
        
        logger.info(f"OAuth disconnection for {provider} by business {business_id}")
        
        return {
            "provider": provider,
            "business_id": business_id,
            "status": "disconnected",
            "disconnected_at": datetime.utcnow().isoformat(),
            "message": f"{OAUTH_CONFIGS[provider]['name']} has been disconnected successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error disconnecting OAuth provider: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to disconnect provider"
        )

@router.get("/status")
async def get_oauth_status(business_id: str):
    """Get OAuth connection status for all providers"""
    try:
        # In production, query database for actual connection status
        # For demo, return mixed connected/disconnected status
        
        connections = []
        demo_statuses = {
            "facebook": {"connected": True, "account": "Demo Barbershop FB Ads"},
            "google": {"connected": True, "account": "Demo Google Ads Account"},
            "square": {"connected": False, "account": None},
            "stripe": {"connected": True, "account": "Demo Stripe Account"}
        }
        
        for provider, config in OAUTH_CONFIGS.items():
            status_info = demo_statuses.get(provider, {"connected": False, "account": None})
            
            connections.append({
                "provider": provider,
                "provider_name": config["name"],
                "status": "connected" if status_info["connected"] else "disconnected",
                "account_name": status_info["account"],
                "scopes": config["scopes"],
                "last_sync": "2 minutes ago" if status_info["connected"] else None,
                "connection_health": "healthy" if status_info["connected"] else "not_connected"
            })
        
        return {
            "business_id": business_id,
            "connections": connections,
            "summary": {
                "total_providers": len(OAUTH_CONFIGS),
                "connected_providers": sum(1 for c in connections if c["status"] == "connected"),
                "connection_health": "good"
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting OAuth status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get OAuth status"
        )

@router.get("/providers")
async def get_available_providers():
    """Get list of available OAuth providers"""
    providers = []
    
    for provider_id, config in OAUTH_CONFIGS.items():
        providers.append({
            "id": provider_id,
            "name": config["name"],
            "scopes": config["scopes"],
            "description": f"Connect your {config['name']} account to track attribution and performance"
        })
    
    return {
        "providers": providers,
        "total_count": len(providers)
    }