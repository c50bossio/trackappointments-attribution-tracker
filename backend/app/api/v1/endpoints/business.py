"""
Business Management Endpoints
Handles business profiles, settings, and configuration
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional
import logging
import time
from datetime import datetime

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/business", tags=["Business Management"])

# In-memory storage (in production, use database)
business_settings_store = {}

class BusinessSettings(BaseModel):
    business_name: str = Field(..., description="Business name")
    default_currency: str = Field("USD", description="Default currency code")
    timezone: str = Field("America/New_York", description="Business timezone")
    industry: Optional[str] = Field("appointment_booking", description="Business industry")

class BusinessSettingsResponse(BaseModel):
    business_id: str
    settings: BusinessSettings
    last_updated: str
    status: str

@router.post("/settings", response_model=BusinessSettingsResponse)
async def save_business_settings(
    business_id: str,
    settings: BusinessSettings
):
    """Save business settings"""
    try:
        logger.info(f"Saving business settings for business_id: {business_id}")
        
        # Validate currency
        valid_currencies = ["USD", "EUR", "GBP", "CAD"]
        if settings.default_currency not in valid_currencies:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid currency. Must be one of: {valid_currencies}"
            )
        
        # Validate timezone
        valid_timezones = [
            "America/New_York",     # Eastern Time
            "America/Chicago",      # Central Time  
            "America/Denver",       # Mountain Time
            "America/Los_Angeles"   # Pacific Time
        ]
        
        timezone_mapping = {
            "Eastern Time (ET)": "America/New_York",
            "Central Time (CT)": "America/Chicago", 
            "Mountain Time (MT)": "America/Denver",
            "Pacific Time (PT)": "America/Los_Angeles"
        }
        
        # Convert display name to timezone if needed
        actual_timezone = timezone_mapping.get(settings.timezone, settings.timezone)
        
        if actual_timezone not in valid_timezones:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid timezone. Must be one of: {list(timezone_mapping.keys())}"
            )
        
        # Store settings (in production, save to database)
        settings_data = {
            "business_name": settings.business_name,
            "default_currency": settings.default_currency,
            "timezone": actual_timezone,
            "industry": settings.industry,
            "last_updated": datetime.utcnow().isoformat(),
            "updated_by": "api"
        }
        
        business_settings_store[business_id] = settings_data
        
        logger.info(f"Business settings saved successfully for {business_id}")
        
        return BusinessSettingsResponse(
            business_id=business_id,
            settings=BusinessSettings(**settings_data),
            last_updated=settings_data["last_updated"],
            status="saved"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving business settings: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save business settings"
        )

@router.get("/settings", response_model=BusinessSettingsResponse)
async def get_business_settings(business_id: str):
    """Get business settings"""
    try:
        if business_id not in business_settings_store:
            # Return default settings for new businesses
            default_settings = BusinessSettings(
                business_name="Your Business Name",
                default_currency="USD",
                timezone="America/New_York",
                industry="appointment_booking"
            )
            
            return BusinessSettingsResponse(
                business_id=business_id,
                settings=default_settings,
                last_updated=datetime.utcnow().isoformat(),
                status="default"
            )
        
        settings_data = business_settings_store[business_id]
        
        return BusinessSettingsResponse(
            business_id=business_id,
            settings=BusinessSettings(**settings_data),
            last_updated=settings_data["last_updated"],
            status="loaded"
        )
        
    except Exception as e:
        logger.error(f"Error getting business settings: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get business settings"
        )

@router.get("/profile")
async def get_business_profile(business_id: str):
    """Get business profile information"""
    try:
        # In production, query database for business profile
        profile_data = {
            "business_id": business_id,
            "name": business_settings_store.get(business_id, {}).get("business_name", "Demo Business"),
            "industry": "appointment_booking",
            "created_at": "2024-01-01T00:00:00Z",
            "status": "active",
            "subscription_plan": "professional",
            "features": {
                "attribution_tracking": True,
                "multi_platform_integration": True,
                "advanced_analytics": True,
                "custom_reporting": True,
                "api_access": True
            },
            "usage": {
                "monthly_interactions": 12847,
                "attribution_accuracy": "94.2%",
                "connected_platforms": 4,
                "recovered_revenue": "$28,450"
            }
        }
        
        return profile_data
        
    except Exception as e:
        logger.error(f"Error getting business profile: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get business profile"
        )

@router.post("/initialize")
async def initialize_business(business_name: str, owner_email: str):
    """Initialize a new business account"""
    try:
        business_id = f"business-{int(time.time())}"
        
        # Initialize default settings
        default_settings = {
            "business_name": business_name,
            "default_currency": "USD", 
            "timezone": "America/New_York",
            "industry": "appointment_booking",
            "last_updated": datetime.utcnow().isoformat(),
            "created_by": owner_email
        }
        
        business_settings_store[business_id] = default_settings
        
        logger.info(f"Business initialized: {business_id} for {owner_email}")
        
        return {
            "business_id": business_id,
            "business_name": business_name,
            "owner_email": owner_email,
            "status": "initialized",
            "next_steps": [
                "Connect your first integration account",
                "Configure attribution settings",
                "Start tracking your first campaign"
            ]
        }
        
    except Exception as e:
        logger.error(f"Error initializing business: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to initialize business"
        )