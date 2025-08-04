"""
Security models for tracking login attempts and account lockouts
"""

import uuid
from datetime import datetime, timedelta
from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.core.types import GUID


class LoginAttempt(Base):
    """Track login attempts for security monitoring."""
    
    __tablename__ = "login_attempts"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id"), nullable=True)  # Can be null for non-existent users
    email = Column(String(255), nullable=False, index=True)
    ip_address = Column(String(45), nullable=False)  # IPv6 support
    user_agent = Column(String(500), nullable=True)
    success = Column(Boolean, default=False, nullable=False)
    failure_reason = Column(String(100), nullable=True)  # "invalid_password", "user_not_found", etc.
    attempted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="login_attempts")
    
    def __repr__(self):
        return f"<LoginAttempt(email='{self.email}', success={self.success}, attempted_at='{self.attempted_at}')>"


class AccountLockout(Base):
    """Track account lockouts due to multiple failed login attempts."""
    
    __tablename__ = "account_lockouts"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False)
    locked_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    unlock_at = Column(DateTime, nullable=False)
    reason = Column(String(200), default="Multiple failed login attempts", nullable=False)
    failed_attempts_count = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    unlocked_at = Column(DateTime, nullable=True)  # When manually or automatically unlocked
    unlocked_by = Column(String(100), nullable=True)  # "system" or admin user ID
    
    # Relationship
    user = relationship("User", back_populates="lockouts")
    
    @property
    def is_locked(self) -> bool:
        """Check if the lockout is still active."""
        if not self.is_active:
            return False
        return datetime.utcnow() < self.unlock_at
    
    @property
    def time_until_unlock(self) -> timedelta:
        """Get the time remaining until automatic unlock."""
        if not self.is_locked:
            return timedelta(0)
        return self.unlock_at - datetime.utcnow()
    
    def unlock(self, unlocked_by: str = "system"):
        """Manually unlock the account."""
        self.is_active = False
        self.unlocked_at = datetime.utcnow()
        self.unlocked_by = unlocked_by
    
    def __repr__(self):
        return f"<AccountLockout(user_id='{self.user_id}', locked_at='{self.locked_at}', is_locked={self.is_locked})>"


class TokenBlacklist(Base):
    """Track blacklisted JWT tokens (for proper logout and security)."""
    
    __tablename__ = "token_blacklist"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    jti = Column(String(255), unique=True, nullable=False, index=True)  # JWT ID from token
    user_id = Column(GUID(), ForeignKey("users.id"), nullable=False)
    token_type = Column(String(20), nullable=False)  # "access" or "refresh"
    blacklisted_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    reason = Column(String(100), default="user_logout", nullable=False)  # "user_logout", "security_breach", etc.
    
    # Relationship
    user = relationship("User", back_populates="blacklisted_tokens")
    
    @property
    def is_expired(self) -> bool:
        """Check if the token has naturally expired."""
        return datetime.utcnow() > self.expires_at
    
    def __repr__(self):
        return f"<TokenBlacklist(jti='{self.jti[:8]}...', user_id='{self.user_id}', blacklisted_at='{self.blacklisted_at}')>"


class SecurityEvent(Base):
    """Log security-related events for audit and monitoring."""
    
    __tablename__ = "security_events"
    
    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id"), nullable=True)  # Can be null for system events
    event_type = Column(String(50), nullable=False, index=True)  # "login_success", "account_locked", etc.
    severity = Column(String(20), default="info", nullable=False)  # "info", "warning", "critical"
    description = Column(String(500), nullable=False)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)
    event_metadata = Column(String(1000), nullable=True)  # JSON string for additional data
    occurred_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="security_events")
    
    def __repr__(self):
        return f"<SecurityEvent(event_type='{self.event_type}', severity='{self.severity}', occurred_at='{self.occurred_at}')>"