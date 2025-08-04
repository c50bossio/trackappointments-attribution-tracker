"""
Facebook Ads API Integration Service
Handles real-time ad performance data and conversion tracking
"""
import os
import asyncio
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import httpx
from facebook_business.api import FacebookAdsApi
from facebook_business.adobjects.adaccount import AdAccount
from facebook_business.adobjects.campaign import Campaign
from facebook_business.adobjects.adset import AdSet
from facebook_business.adobjects.ad import Ad
from facebook_business.adobjects.adsinsights import AdsInsights
from facebook_business.exceptions import FacebookError

logger = logging.getLogger(__name__)

class FacebookAdsService:
    """Service for integrating with Facebook Ads API"""
    
    def __init__(self):
        self.app_id = os.getenv("FACEBOOK_APP_ID")
        self.app_secret = os.getenv("FACEBOOK_APP_SECRET")
        self.access_token = os.getenv("FACEBOOK_ACCESS_TOKEN")
        self.api = None
        
        if self.app_id and self.app_secret and self.access_token:
            try:
                FacebookAdsApi.init(
                    app_id=self.app_id,
                    app_secret=self.app_secret,
                    access_token=self.access_token
                )
                self.api = FacebookAdsApi.get_default_api()
                logger.info("Facebook Ads API initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Facebook Ads API: {e}")
        else:
            logger.warning("Facebook Ads API credentials not configured")
    
    async def get_account_campaigns(self, ad_account_id: str) -> List[Dict[str, Any]]:
        """Get all campaigns for an ad account"""
        if not self.api:
            logger.error("Facebook Ads API not initialized")
            return []
        
        try:
            account = AdAccount(f"act_{ad_account_id}")
            campaigns = account.get_campaigns(fields=[
                Campaign.Field.id,
                Campaign.Field.name,
                Campaign.Field.status,
                Campaign.Field.objective,
                Campaign.Field.created_time,
                Campaign.Field.updated_time
            ])
            
            return [
                {
                    "id": campaign.get("id"),
                    "name": campaign.get("name"),
                    "status": campaign.get("status"),
                    "objective": campaign.get("objective"),
                    "created_time": campaign.get("created_time"),
                    "updated_time": campaign.get("updated_time")
                }
                for campaign in campaigns
            ]
        except FacebookError as e:
            logger.error(f"Error fetching campaigns: {e}")
            return []
    
    async def get_campaign_insights(
        self, 
        campaign_id: str, 
        date_from: datetime,
        date_to: datetime
    ) -> Dict[str, Any]:
        """Get performance insights for a specific campaign"""
        if not self.api:
            logger.error("Facebook Ads API not initialized")
            return {}
        
        try:
            campaign = Campaign(campaign_id)
            insights = campaign.get_insights(
                fields=[
                    AdsInsights.Field.campaign_id,
                    AdsInsights.Field.campaign_name,
                    AdsInsights.Field.impressions,
                    AdsInsights.Field.clicks,
                    AdsInsights.Field.spend,
                    AdsInsights.Field.cpm,
                    AdsInsights.Field.cpc,
                    AdsInsights.Field.ctr,
                    AdsInsights.Field.reach,
                    AdsInsights.Field.frequency,
                    AdsInsights.Field.conversions,
                    AdsInsights.Field.cost_per_conversion
                ],
                params={
                    'time_range': {
                        'since': date_from.strftime('%Y-%m-%d'),
                        'until': date_to.strftime('%Y-%m-%d')
                    },
                    'level': 'campaign'
                }
            )
            
            if insights:
                insight = insights[0]
                return {
                    "campaign_id": insight.get("campaign_id"),
                    "campaign_name": insight.get("campaign_name"),
                    "impressions": int(insight.get("impressions", 0)),
                    "clicks": int(insight.get("clicks", 0)),
                    "spend": float(insight.get("spend", 0)),
                    "cpm": float(insight.get("cpm", 0)),
                    "cpc": float(insight.get("cpc", 0)),
                    "ctr": float(insight.get("ctr", 0)),
                    "reach": int(insight.get("reach", 0)),
                    "frequency": float(insight.get("frequency", 0)),
                    "conversions": int(insight.get("conversions", 0)),
                    "cost_per_conversion": float(insight.get("cost_per_conversion", 0))
                }
            return {}
        except FacebookError as e:
            logger.error(f"Error fetching campaign insights: {e}")
            return {}
    
    async def track_ad_click(self, click_data: Dict[str, Any]) -> bool:
        """Track an ad click event for attribution"""
        try:
            # Extract UTM parameters and Facebook click ID
            fbclid = click_data.get("fbclid")
            utm_source = click_data.get("utm_source")
            utm_campaign = click_data.get("utm_campaign")
            utm_content = click_data.get("utm_content")
            
            if not fbclid or utm_source != "facebook":
                logger.warning("Invalid Facebook ad click data")
                return False
            
            # Store click data for attribution matching
            click_record = {
                "platform": "facebook",
                "click_id": fbclid,
                "campaign_id": utm_campaign,
                "ad_content": utm_content,
                "timestamp": datetime.utcnow(),
                "user_agent": click_data.get("user_agent"),
                "ip_address": click_data.get("ip_address"),
                "referrer": click_data.get("referrer")
            }
            
            # TODO: Store in database for attribution matching
            logger.info(f"Tracked Facebook ad click: {fbclid}")
            return True
            
        except Exception as e:
            logger.error(f"Error tracking Facebook ad click: {e}")
            return False
    
    async def send_conversion_event(self, conversion_data: Dict[str, Any]) -> bool:
        """Send conversion event back to Facebook via Conversions API"""
        if not self.api:
            logger.error("Facebook Ads API not initialized")
            return False
        
        try:
            # Prepare conversion event data
            event_data = {
                "event_name": "Purchase",  # or "Lead" for appointment bookings
                "event_time": int(conversion_data.get("timestamp", datetime.utcnow()).timestamp()),
                "event_source_url": conversion_data.get("source_url"),
                "user_data": {
                    "em": conversion_data.get("email_hash"),  # SHA256 hashed email
                    "ph": conversion_data.get("phone_hash"),  # SHA256 hashed phone
                    "client_ip_address": conversion_data.get("ip_address"),
                    "client_user_agent": conversion_data.get("user_agent")
                },
                "custom_data": {
                    "currency": "USD",
                    "value": conversion_data.get("value", 0),
                    "content_type": "appointment",
                    "content_name": conversion_data.get("service_name")
                }
            }
            
            # Add Facebook click ID if available
            if conversion_data.get("fbclid"):
                event_data["user_data"]["fbc"] = conversion_data["fbclid"]
            
            # TODO: Implement actual Conversions API call
            # This requires the facebook-business-sdk with Conversions API setup
            logger.info(f"Would send conversion event to Facebook: {event_data}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending conversion to Facebook: {e}")
            return False
    
    async def get_real_time_metrics(self, ad_account_id: str) -> Dict[str, Any]:
        """Get real-time advertising metrics"""
        if not self.api:
            return {
                "total_spend": 0,
                "total_clicks": 0,
                "total_impressions": 0,
                "active_campaigns": 0,
                "avg_cpc": 0,
                "avg_ctr": 0
            }
        
        try:
            # Get today's metrics
            today = datetime.now()
            yesterday = today - timedelta(days=1)
            
            account = AdAccount(f"act_{ad_account_id}")
            insights = account.get_insights(
                fields=[
                    AdsInsights.Field.spend,
                    AdsInsights.Field.clicks,
                    AdsInsights.Field.impressions,
                    AdsInsights.Field.cpc,
                    AdsInsights.Field.ctr
                ],
                params={
                    'time_range': {
                        'since': yesterday.strftime('%Y-%m-%d'),
                        'until': today.strftime('%Y-%m-%d')
                    },
                    'level': 'account'
                }
            )
            
            if insights:
                insight = insights[0]
                return {
                    "total_spend": float(insight.get("spend", 0)),
                    "total_clicks": int(insight.get("clicks", 0)),
                    "total_impressions": int(insight.get("impressions", 0)),
                    "active_campaigns": len(await self.get_account_campaigns(ad_account_id)),
                    "avg_cpc": float(insight.get("cpc", 0)),
                    "avg_ctr": float(insight.get("ctr", 0))
                }
            
            return {
                "total_spend": 0,
                "total_clicks": 0,
                "total_impressions": 0,
                "active_campaigns": 0,
                "avg_cpc": 0,
                "avg_ctr": 0
            }
            
        except FacebookError as e:
            logger.error(f"Error fetching real-time metrics: {e}")
            return {
                "total_spend": 0,
                "total_clicks": 0,
                "total_impressions": 0,
                "active_campaigns": 0,
                "avg_cpc": 0,
                "avg_ctr": 0
            }
    
    def is_configured(self) -> bool:
        """Check if Facebook Ads API is properly configured"""
        return all([self.app_id, self.app_secret, self.access_token, self.api])

# Global instance
facebook_ads_service = FacebookAdsService()