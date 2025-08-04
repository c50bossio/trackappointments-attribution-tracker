"""
Square Booking Integration Service
Handles real-time appointment booking data and webhook processing
"""
import os
import asyncio
import logging
import hashlib
import hmac
from typing import Dict, List, Optional, Any
from datetime import datetime
import httpx
# Note: Using httpx for now instead of Square SDK due to import issues
# from squareup import Client as SquareClient
# from squareup.models import CreateBookingRequest, SearchBookingsRequest
# from squareup.exceptions import ApiException

logger = logging.getLogger(__name__)

class SquareBookingService:
    """Service for integrating with Square Bookings API"""
    
    def __init__(self):
        self.application_id = os.getenv("SQUARE_APPLICATION_ID")
        self.access_token = os.getenv("SQUARE_ACCESS_TOKEN")
        self.webhook_signature_key = os.getenv("SQUARE_WEBHOOK_SIGNATURE_KEY")
        self.environment = os.getenv("SQUARE_ENVIRONMENT", "sandbox")  # sandbox or production
        
        # Initialize HTTP client for Square API calls
        self.http_client = httpx.AsyncClient()
        self.base_url = "https://connect.squareup.com" if self.environment == "production" else "https://connect.squareupsandbox.com"
        
        if self.access_token:
            self.headers = {
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json",
                "Square-Version": "2023-10-18"  # Latest API version
            }
            logger.info(f"Square API initialized successfully (env: {self.environment})")
        else:
            logger.warning("Square API credentials not configured")
            self.headers = {}
    
    async def get_recent_bookings(self, location_id: str, days: int = 7) -> List[Dict[str, Any]]:
        """Get recent bookings for a location"""
        if not self.client:
            logger.error("Square API not initialized")
            return []
        
        try:
            # Calculate date range
            end_date = datetime.utcnow()
            start_date = end_date.replace(hour=0, minute=0, second=0, microsecond=0)
            start_date = start_date.replace(day=start_date.day - days)
            
            # Search for bookings
            search_request = SearchBookingsRequest(
                filter={
                    'location_id': location_id,
                    'start_at_range': {
                        'start_at': start_date.isoformat() + 'Z',
                        'end_at': end_date.isoformat() + 'Z'
                    }
                }
            )
            
            result = self.bookings_api.search_bookings(body={'query': search_request})
            
            if result.is_success():
                bookings = result.body.get('bookings', [])
                return [
                    {
                        "id": booking.get("id"),
                        "status": booking.get("status"),
                        "start_at": booking.get("appointment_segments", [{}])[0].get("start_at"),
                        "duration_minutes": booking.get("appointment_segments", [{}])[0].get("duration_minutes"),
                        "service_variation_id": booking.get("appointment_segments", [{}])[0].get("service_variation_id"),
                        "team_member_id": booking.get("appointment_segments", [{}])[0].get("team_member_id"),
                        "customer_id": booking.get("customer_id"),
                        "location_id": booking.get("location_id"),
                        "created_at": booking.get("created_at"),
                        "updated_at": booking.get("updated_at"),
                        "source": booking.get("source")
                    }
                    for booking in bookings
                ]
            else:
                logger.error(f"Error fetching bookings: {result.errors}")
                return []
                
        except ApiException as e:
            logger.error(f"Square API error fetching bookings: {e}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error fetching bookings: {e}")
            return []
    
    async def get_customer_details(self, customer_id: str) -> Optional[Dict[str, Any]]:
        """Get customer details for attribution matching"""
        if not self.client:
            logger.error("Square API not initialized")
            return None
        
        try:
            result = self.customers_api.retrieve_customer(customer_id)
            
            if result.is_success():
                customer = result.body.get('customer', {})
                return {
                    "id": customer.get("id"),
                    "given_name": customer.get("given_name"),
                    "family_name": customer.get("family_name"),
                    "email_address": customer.get("email_address"),
                    "phone_number": customer.get("phone_number"),
                    "created_at": customer.get("created_at"),
                    "updated_at": customer.get("updated_at")
                }
            else:
                logger.error(f"Error fetching customer: {result.errors}")
                return None
                
        except ApiException as e:
            logger.error(f"Square API error fetching customer: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error fetching customer: {e}")
            return None
    
    async def process_booking_webhook(self, webhook_data: Dict[str, Any]) -> bool:
        """Process incoming booking webhook from Square"""
        try:
            event_type = webhook_data.get("type")
            event_data = webhook_data.get("data", {})
            
            if event_type not in ["booking.created", "booking.updated"]:
                logger.info(f"Ignoring webhook event type: {event_type}")
                return True
            
            booking_id = event_data.get("id")
            if not booking_id:
                logger.error("Webhook missing booking ID")
                return False
            
            # Extract booking details
            booking_info = {
                "platform": "square",
                "booking_id": booking_id,
                "status": event_data.get("status"),
                "customer_id": event_data.get("customer_id"),
                "location_id": event_data.get("location_id"),
                "created_at": event_data.get("created_at"),
                "service_details": event_data.get("appointment_segments", [])
            }
            
            # Get customer details for attribution matching
            if booking_info["customer_id"]:
                customer = await self.get_customer_details(booking_info["customer_id"])
                if customer:
                    booking_info["customer"] = customer
            
            # Process for attribution matching
            await self._process_for_attribution(booking_info)
            
            logger.info(f"Processed Square booking webhook: {booking_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error processing Square booking webhook: {e}")
            return False
    
    async def _process_for_attribution(self, booking_info: Dict[str, Any]) -> None:
        """Process booking for attribution matching"""
        try:
            # Extract customer identifiers for matching
            customer = booking_info.get("customer", {})
            email = customer.get("email_address")
            phone = customer.get("phone_number")
            
            if not email and not phone:
                logger.warning("Booking has no email or phone for attribution matching")
                return
            
            # Create privacy-safe hashes for matching
            hash_salt = os.getenv("HASH_SALT", "default-salt")
            
            identifiers = {}
            if email:
                identifiers["email_hash"] = hashlib.sha256(
                    (email.lower() + hash_salt).encode()
                ).hexdigest()
            
            if phone:
                # Normalize phone number (remove spaces, dashes, etc.)
                clean_phone = ''.join(filter(str.isdigit, phone))
                identifiers["phone_hash"] = hashlib.sha256(
                    (clean_phone + hash_salt).encode()
                ).hexdigest()
            
            # Prepare attribution data
            attribution_data = {
                "event_type": "booking_created",
                "booking_id": booking_info["booking_id"],
                "platform": "square",
                "timestamp": datetime.utcnow(),
                "identifiers": identifiers,
                "booking_value": await self._calculate_booking_value(booking_info),
                "service_details": booking_info.get("service_details", [])
            }
            
            # TODO: Store in database and trigger attribution matching
            logger.info(f"Prepared attribution data for booking: {booking_info['booking_id']}")
            
        except Exception as e:
            logger.error(f"Error processing booking for attribution: {e}")
    
    async def _calculate_booking_value(self, booking_info: Dict[str, Any]) -> float:
        """Calculate estimated booking value"""
        try:
            # For now, use average barbershop service prices
            # In production, this would come from Square's pricing data
            service_segments = booking_info.get("service_details", [])
            
            # Default pricing for common barbershop services
            default_prices = {
                "haircut": 45.0,
                "beard_trim": 25.0,
                "shampoo": 15.0,
                "styling": 35.0,
                "full_service": 75.0
            }
            
            total_value = 0.0
            for segment in service_segments:
                # Try to estimate based on duration or service type
                duration = segment.get("duration_minutes", 60)
                if duration <= 30:
                    total_value += default_prices["beard_trim"]
                elif duration <= 60:
                    total_value += default_prices["haircut"]
                else:
                    total_value += default_prices["full_service"]
            
            return max(total_value, 35.0)  # Minimum $35 booking value
            
        except Exception as e:
            logger.error(f"Error calculating booking value: {e}")
            return 45.0  # Default haircut price
    
    def verify_webhook_signature(self, payload: str, signature: str) -> bool:
        """Verify Square webhook signature"""
        if not self.webhook_signature_key:
            logger.warning("Webhook signature key not configured")
            return True  # Allow in development
        
        try:
            expected_signature = hmac.new(
                self.webhook_signature_key.encode(),
                payload.encode(),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
            
        except Exception as e:
            logger.error(f"Error verifying webhook signature: {e}")
            return False
    
    async def get_business_metrics(self, location_id: str) -> Dict[str, Any]:
        """Get real-time business metrics from Square"""
        if not self.client:
            return {
                "total_bookings_today": 0,
                "total_bookings_week": 0,
                "estimated_revenue_today": 0,
                "estimated_revenue_week": 0,
                "average_booking_value": 45.0
            }
        
        try:
            # Get today's bookings
            today_bookings = await self.get_recent_bookings(location_id, days=1)
            week_bookings = await self.get_recent_bookings(location_id, days=7)
            
            # Calculate metrics
            today_count = len(today_bookings)
            week_count = len(week_bookings)
            
            # Estimate revenue (in production, get actual pricing data)
            avg_booking_value = 45.0
            today_revenue = today_count * avg_booking_value
            week_revenue = week_count * avg_booking_value
            
            return {
                "total_bookings_today": today_count,
                "total_bookings_week": week_count,
                "estimated_revenue_today": today_revenue,
                "estimated_revenue_week": week_revenue,
                "average_booking_value": avg_booking_value
            }
            
        except Exception as e:
            logger.error(f"Error fetching business metrics: {e}")
            return {
                "total_bookings_today": 0,
                "total_bookings_week": 0,
                "estimated_revenue_today": 0,
                "estimated_revenue_week": 0,
                "average_booking_value": 45.0
            }
    
    def is_configured(self) -> bool:
        """Check if Square API is properly configured"""
        return bool(self.access_token and self.client)

# Global instance
square_booking_service = SquareBookingService()