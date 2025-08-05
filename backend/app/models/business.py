"""
Business models for TrackAppointments platform
"""
from sqlalchemy import Column, String, DateTime, Float, Boolean, Text, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid

Base = declarative_base()

class Business(Base):
    """Business model for multi-tenant support"""
    __tablename__ = "businesses"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    owner_email = Column(String(255), nullable=False)
    industry = Column(String(100), default="appointment_booking")
    
    # Business settings
    default_currency = Column(String(3), default="USD")
    timezone = Column(String(50), default="America/New_York")
    business_hours = Column(JSON, default=lambda: {
        "monday": {"open": "09:00", "close": "18:00", "closed": False},
        "tuesday": {"open": "09:00", "close": "18:00", "closed": False},
        "wednesday": {"open": "09:00", "close": "18:00", "closed": False},
        "thursday": {"open": "09:00", "close": "18:00", "closed": False},
        "friday": {"open": "09:00", "close": "18:00", "closed": False},
        "saturday": {"open": "10:00", "close": "16:00", "closed": False},
        "sunday": {"open": "10:00", "close": "16:00", "closed": True}
    })
    
    # Attribution settings
    attribution_model = Column(String(50), default="ml-enhanced")
    attribution_window_days = Column(Float, default=7.0)
    minimum_confidence_threshold = Column(Float, default=85.0)
    
    # Integration settings
    facebook_connected = Column(Boolean, default=False)
    google_connected = Column(Boolean, default=False)
    square_connected = Column(Boolean, default=False)
    stripe_connected = Column(Boolean, default=False)
    
    # OAuth tokens (encrypted in production)
    facebook_access_token = Column(Text, nullable=True)
    google_access_token = Column(Text, nullable=True)
    square_access_token = Column(Text, nullable=True)
    stripe_access_token = Column(Text, nullable=True)
    
    # Business metrics
    total_bookings = Column(Float, default=0.0)
    total_revenue = Column(Float, default=0.0)
    attribution_accuracy = Column(Float, default=0.0)
    recovered_revenue = Column(Float, default=0.0)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)
    subscription_plan = Column(String(50), default="starter")
    
    def to_dict(self):
        """Convert business to dictionary"""
        return {
            "id": str(self.id),
            "name": self.name,
            "owner_email": self.owner_email,
            "industry": self.industry,
            "settings": {
                "currency": self.default_currency,
                "timezone": self.timezone,
                "business_hours": self.business_hours,
                "attribution_model": self.attribution_model,
                "attribution_window_days": self.attribution_window_days,
                "confidence_threshold": self.minimum_confidence_threshold
            },
            "integrations": {
                "facebook_ads": self.facebook_connected,
                "google_ads": self.google_connected,
                "square_payments": self.square_connected,
                "stripe_payments": self.stripe_connected
            },
            "metrics": {
                "total_bookings": self.total_bookings,
                "total_revenue": self.total_revenue,
                "attribution_accuracy": self.attribution_accuracy,
                "recovered_revenue": self.recovered_revenue
            },
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "subscription_plan": self.subscription_plan,
            "is_active": self.is_active
        }

class User(Base):
    """User model for authentication"""
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    
    # User profile
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    role = Column(String(50), default="admin")  # admin, manager, viewer
    
    # Settings
    timezone = Column(String(50), nullable=True)
    email_notifications = Column(Boolean, default=True)
    sms_notifications = Column(Boolean, default=False)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    email_verified = Column(Boolean, default=False)
    
    def to_dict(self):
        """Convert user to dictionary"""
        return {
            "id": str(self.id),
            "email": self.email,
            "business_id": str(self.business_id),
            "profile": {
                "first_name": self.first_name,
                "last_name": self.last_name,
                "role": self.role
            },
            "settings": {
                "timezone": self.timezone,
                "email_notifications": self.email_notifications,
                "sms_notifications": self.sms_notifications
            },
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_login": self.last_login.isoformat() if self.last_login else None,
            "is_active": self.is_active,
            "email_verified": self.email_verified
        }

class AttributionEvent(Base):
    """Attribution event tracking"""
    __tablename__ = "attribution_events"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    business_id = Column(UUID(as_uuid=True), nullable=False)
    
    # Event details
    event_type = Column(String(50), nullable=False)  # interaction, conversion, booking
    source = Column(String(100), nullable=False)  # facebook_ads, google_ads, organic
    campaign_id = Column(String(255), nullable=True)
    user_identifier = Column(String(255), nullable=False)  # Privacy-safe hash
    
    # Attribution data
    interaction_value = Column(Float, default=0.0)
    conversion_value = Column(Float, default=0.0)
    attribution_weight = Column(Float, default=1.0)
    confidence_score = Column(Float, default=0.0)
    
    # Metadata
    event_data = Column(JSON, default=dict)
    timestamp = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime, nullable=True)
    attribution_model_used = Column(String(50), nullable=True)
    
    def to_dict(self):
        """Convert event to dictionary"""
        return {
            "id": str(self.id),
            "business_id": str(self.business_id),
            "event_type": self.event_type,
            "source": self.source,
            "campaign_id": self.campaign_id,
            "user_identifier": self.user_identifier,
            "interaction_value": self.interaction_value,
            "conversion_value": self.conversion_value,
            "attribution_weight": self.attribution_weight,
            "confidence_score": self.confidence_score,
            "event_data": self.event_data,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "processed_at": self.processed_at.isoformat() if self.processed_at else None,
            "attribution_model_used": self.attribution_model_used
        }