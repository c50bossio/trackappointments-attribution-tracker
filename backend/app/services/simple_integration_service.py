"""
Simplified Integration Service for Demo/Development
Provides integration status and demo data without complex SDK dependencies
"""
import os
import logging
from typing import Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)

class SimpleIntegrationService:
    """Simplified service for integration status and demo data"""
    
    def __init__(self):
        self.facebook_configured = bool(
            os.getenv("FACEBOOK_APP_ID") and 
            os.getenv("FACEBOOK_APP_SECRET") and 
            os.getenv("FACEBOOK_ACCESS_TOKEN")
        )
        self.square_configured = bool(
            os.getenv("SQUARE_APPLICATION_ID") and 
            os.getenv("SQUARE_ACCESS_TOKEN")
        )
        self.google_configured = bool(
            os.getenv("GOOGLE_ADS_DEVELOPER_TOKEN") and 
            os.getenv("GOOGLE_ADS_CLIENT_ID")
        )
    
    def get_integration_status(self) -> Dict[str, Any]:
        """Get current integration status"""
        return {
            "success": True,
            "data": {
                "facebook_ads": {
                    "configured": self.facebook_configured,
                    "status": "connected" if self.facebook_configured else "setup_required",
                    "description": "Facebook Ads API for conversion tracking and campaign data"
                },
                "square_booking": {
                    "configured": self.square_configured,
                    "status": "connected" if self.square_configured else "setup_required",
                    "description": "Square Bookings API for appointment data and webhooks"
                },
                "google_ads": {
                    "configured": self.google_configured,
                    "status": "connected" if self.google_configured else "setup_required",
                    "description": "Google Ads API for search campaign attribution"
                }
            },
            "summary": {
                "total_integrations": 3,
                "configured_integrations": sum([
                    self.facebook_configured,
                    self.square_configured, 
                    self.google_configured
                ]),
                "platform_ready": all([
                    self.facebook_configured,
                    self.square_configured
                ])  # Google Ads is optional for basic functionality
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def get_facebook_demo_metrics(self, ad_account_id: str) -> Dict[str, Any]:
        """Get demo Facebook Ads metrics"""
        return {
            "success": True,
            "data": {
                "ad_account_id": ad_account_id,
                "metrics": {
                    "total_spend": 1247.83,
                    "total_clicks": 342,
                    "total_impressions": 12847,
                    "active_campaigns": 3,
                    "avg_cpc": 3.65,
                    "avg_ctr": 2.66,
                    "conversions": 23,
                    "cost_per_conversion": 54.20
                },
                "is_demo_data": not self.facebook_configured
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def get_square_demo_bookings(self, location_id: str) -> Dict[str, Any]:
        """Get demo Square booking data"""
        return {
            "success": True,
            "data": {
                "location_id": location_id,
                "bookings": [
                    {
                        "id": "booking_demo_001",
                        "status": "ACCEPTED",
                        "customer_name": "John D.",
                        "service_name": "Premium Cut & Styling",
                        "start_time": (datetime.now()).isoformat(),
                        "duration_minutes": 60,
                        "booking_value": 85.0,
                        "attribution_source": "Facebook Ads",
                        "attribution_confidence": 96.8
                    },
                    {
                        "id": "booking_demo_002", 
                        "status": "ACCEPTED",
                        "customer_name": "Mike R.",
                        "service_name": "Beard Trim",
                        "start_time": (datetime.now()).isoformat(),
                        "duration_minutes": 30,
                        "booking_value": 35.0,
                        "attribution_source": "Google Search",
                        "attribution_confidence": 89.2
                    }
                ],
                "metrics": {
                    "total_bookings_today": 8,
                    "total_bookings_week": 47,
                    "estimated_revenue_today": 420.0,
                    "estimated_revenue_week": 2485.0,
                    "average_booking_value": 52.87
                },
                "is_demo_data": not self.square_configured
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def get_setup_guide(self) -> Dict[str, Any]:
        """Get setup guide for all integrations"""
        return {
            "success": True,
            "data": {
                "facebook_ads": {
                    "status": "configured" if self.facebook_configured else "setup_required",
                    "required_env_vars": [
                        "FACEBOOK_APP_ID",
                        "FACEBOOK_APP_SECRET", 
                        "FACEBOOK_ACCESS_TOKEN"
                    ],
                    "setup_steps": [
                        "1. Go to https://developers.facebook.com/apps/",
                        "2. Create a new app or select existing app",
                        "3. Add 'Marketing API' product",
                        "4. Generate access token with ads_read permissions",
                        "5. Update .env file with credentials",
                        "6. Restart backend server"
                    ],
                    "documentation_url": "https://developers.facebook.com/docs/marketing-api"
                },
                "square_booking": {
                    "status": "configured" if self.square_configured else "setup_required",
                    "required_env_vars": [
                        "SQUARE_APPLICATION_ID",
                        "SQUARE_ACCESS_TOKEN",
                        "SQUARE_WEBHOOK_SIGNATURE_KEY (optional)"
                    ],
                    "setup_steps": [
                        "1. Go to https://developer.squareup.com/apps",
                        "2. Create new application or select existing",
                        "3. Get Application ID and Access Token",
                        "4. Configure webhook endpoints (optional)",
                        "5. Update .env file with credentials",
                        "6. Restart backend server"
                    ],
                    "documentation_url": "https://developer.squareup.com/docs/bookings-api"
                },
                "google_ads": {
                    "status": "configured" if self.google_configured else "setup_required",
                    "required_env_vars": [
                        "GOOGLE_ADS_DEVELOPER_TOKEN",
                        "GOOGLE_ADS_CLIENT_ID",
                        "GOOGLE_ADS_CLIENT_SECRET",
                        "GOOGLE_ADS_REFRESH_TOKEN"
                    ],
                    "setup_steps": [
                        "1. Apply for Google Ads API developer token",
                        "2. Create OAuth 2.0 credentials in Google Cloud Console",
                        "3. Complete OAuth flow to get refresh token",
                        "4. Update .env file with credentials",
                        "5. Restart backend server"
                    ],
                    "documentation_url": "https://developers.google.com/google-ads/api",
                    "note": "Optional - Required only for Google Ads attribution"
                }
            },
            "quick_setup": {
                "script_path": "./scripts/setup-real-data-integration.sh",
                "description": "Run the interactive setup script to configure all integrations",
                "command": "cd scripts && ./setup-real-data-integration.sh"
            },
            "timestamp": datetime.utcnow().isoformat()
        }

# Global instance
simple_integration_service = SimpleIntegrationService()