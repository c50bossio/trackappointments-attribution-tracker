"""Google Ads integration models for storing credentials and sync data"""

import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import Column, String, DateTime, Numeric, ForeignKey, Integer, Boolean, Text, JSON
from sqlalchemy.orm import relationship

from app.core.types import GUID
from app.core.database import Base


class GoogleAdsAccount(Base):
    """Google Ads account integration model"""
    
    __tablename__ = "google_ads_accounts"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    business_id = Column(GUID(), ForeignKey("businesses.id"), nullable=False)
    
    # Google Ads account info
    customer_id = Column(String(20), nullable=False, unique=True)  # Google Ads customer ID
    account_name = Column(String(255), nullable=True)
    currency_code = Column(String(3), nullable=True)
    time_zone = Column(String(50), nullable=True)
    
    # OAuth 2.0 credentials (encrypted)
    refresh_token = Column(Text, nullable=False)  # Encrypted refresh token
    client_id = Column(String(255), nullable=False)
    client_secret = Column(Text, nullable=False)  # Encrypted client secret
    developer_token = Column(Text, nullable=False)  # Encrypted developer token
    
    # Integration status
    status = Column(String(20), default="active", nullable=False)  # active, inactive, error
    last_sync_at = Column(DateTime, nullable=True)
    last_error = Column(Text, nullable=True)
    
    # Sync configuration
    auto_sync_enabled = Column(Boolean, default=True, nullable=False)
    sync_campaigns = Column(Boolean, default=True, nullable=False)
    sync_conversions = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationships
    business = relationship("Business", back_populates="google_ads_accounts")
    conversion_actions = relationship("GoogleAdsConversionAction", back_populates="account", cascade="all, delete-orphan")
    campaign_syncs = relationship("GoogleAdsCampaignSync", back_populates="account", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<GoogleAdsAccount(customer_id='{self.customer_id}', status='{self.status}')>"


class GoogleAdsConversionAction(Base):
    """Google Ads conversion action model"""
    
    __tablename__ = "google_ads_conversion_actions"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    account_id = Column(GUID(), ForeignKey("google_ads_accounts.id"), nullable=False)
    
    # Conversion action details
    conversion_action_id = Column(String(50), nullable=False)  # Google Ads conversion action ID
    name = Column(String(255), nullable=False)
    type = Column(String(50), nullable=True)
    status = Column(String(20), nullable=False)  # ENABLED, PAUSED, REMOVED
    category = Column(String(50), nullable=True)
    
    # Attribution settings
    attribution_model = Column(String(50), nullable=True)
    click_through_lookback_window_days = Column(Integer, nullable=True)
    view_through_lookback_window_days = Column(Integer, nullable=True)
    
    # BookingBridge mapping
    is_default_booking_action = Column(Boolean, default=False, nullable=False)
    booking_value_multiplier = Column(Numeric(5, 2), default=Decimal('1.00'), nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationships
    account = relationship("GoogleAdsAccount", back_populates="conversion_actions")
    
    # Unique constraint per account
    __table_args__ = (
        {"extend_existing": True}
    )
    
    def __repr__(self):
        return f"<GoogleAdsConversionAction(name='{self.name}', status='{self.status}')>"


class GoogleAdsCampaignSync(Base):
    """Google Ads campaign synchronization data"""
    
    __tablename__ = "google_ads_campaign_syncs"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    account_id = Column(GUID(), ForeignKey("google_ads_accounts.id"), nullable=False)
    
    # Google Ads campaign info
    google_campaign_id = Column(String(50), nullable=False)
    campaign_name = Column(String(255), nullable=False)
    campaign_status = Column(String(20), nullable=False)
    
    # Campaign dates
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    
    # Budget and performance metrics
    budget_amount = Column(Numeric(12, 2), nullable=True)
    impressions = Column(Integer, default=0, nullable=False)
    clicks = Column(Integer, default=0, nullable=False)
    cost = Column(Numeric(12, 2), default=Decimal('0.00'), nullable=False)
    conversions = Column(Numeric(8, 2), default=Decimal('0.00'), nullable=False)
    conversion_value = Column(Numeric(12, 2), default=Decimal('0.00'), nullable=False)
    ctr = Column(Numeric(6, 4), default=Decimal('0.00'), nullable=False)  # Click-through rate
    cpc = Column(Numeric(8, 2), default=Decimal('0.00'), nullable=False)  # Cost per click
    
    # Sync metadata
    sync_date = Column(DateTime, default=datetime.utcnow, nullable=False)
    data_date_start = Column(DateTime, nullable=False)  # Date range start for this sync
    data_date_end = Column(DateTime, nullable=False)    # Date range end for this sync
    
    # BookingBridge campaign mapping
    local_campaign_id = Column(GUID(), ForeignKey("campaigns.id"), nullable=True)
    auto_mapped = Column(Boolean, default=False, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    # Relationships
    account = relationship("GoogleAdsAccount", back_populates="campaign_syncs")
    local_campaign = relationship("Campaign", foreign_keys=[local_campaign_id])
    
    def __repr__(self):
        return f"<GoogleAdsCampaignSync(name='{self.campaign_name}', sync_date='{self.sync_date}')>"


class GoogleAdsConversionUpload(Base):
    """Track conversion uploads to Google Ads"""
    
    __tablename__ = "google_ads_conversion_uploads"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    account_id = Column(GUID(), ForeignKey("google_ads_accounts.id"), nullable=False)
    attribution_id = Column(GUID(), ForeignKey("attributions.id"), nullable=False)
    conversion_action_id = Column(String(50), nullable=False)
    
    # Upload details
    conversion_date_time = Column(DateTime, nullable=False)
    conversion_value = Column(Numeric(10, 2), nullable=False)
    currency_code = Column(String(3), default="USD", nullable=False)
    order_id = Column(String(100), nullable=True)
    
    # User identifiers used (for privacy tracking)
    user_identifier_types = Column(JSON, nullable=True)  # ["hashed_email", "hashed_phone"]
    gclid = Column(String(255), nullable=True)
    
    # Upload status
    upload_status = Column(String(20), default="pending", nullable=False)  # pending, success, failed
    upload_response = Column(JSON, nullable=True)  # Google Ads API response
    error_message = Column(Text, nullable=True)
    
    # Retry tracking
    retry_count = Column(Integer, default=0, nullable=False)
    next_retry_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    uploaded_at = Column(DateTime, nullable=True)
    
    # Relationships
    account = relationship("GoogleAdsAccount")
    attribution = relationship("Attribution")
    
    def __repr__(self):
        return f"<GoogleAdsConversionUpload(value={self.conversion_value}, status='{self.upload_status}')>"


class GoogleAdsSyncLog(Base):
    """Log Google Ads synchronization activities"""
    
    __tablename__ = "google_ads_sync_logs"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    account_id = Column(GUID(), ForeignKey("google_ads_accounts.id"), nullable=False)
    
    # Sync details
    sync_type = Column(String(50), nullable=False)  # campaigns, conversion_actions, conversions
    sync_status = Column(String(20), nullable=False)  # success, partial, failed
    
    # Results
    records_processed = Column(Integer, default=0, nullable=False)
    records_successful = Column(Integer, default=0, nullable=False)
    records_failed = Column(Integer, default=0, nullable=False)
    
    # Error details
    error_message = Column(Text, nullable=True)
    error_details = Column(JSON, nullable=True)
    
    # Performance metrics
    sync_duration_seconds = Column(Numeric(8, 2), nullable=True)
    
    # Timestamps
    started_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    account = relationship("GoogleAdsAccount")
    
    def __repr__(self):
        return f"<GoogleAdsSyncLog(type='{self.sync_type}', status='{self.sync_status}')>"