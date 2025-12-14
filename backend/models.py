from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime
import re


# OAuth Models
class GoogleOAuthLogin(BaseModel):
    """Model for Google OAuth login"""
    id_token: str
    user_type: str = Field(..., pattern="^(user|merchant)$")  # Either user or merchant


class MerchantOAuthProfileComplete(BaseModel):
    """Model for completing merchant OAuth profile"""
    merchant_id: str
    store_name: str = Field(..., min_length=1, max_length=100)
    owner_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, min_length=10, max_length=10)
    store_address: Optional[str] = Field(None, max_length=200)
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and not re.match(r'^\d{10}$', v):
            raise ValueError('Phone must be exactly 10 digits')
        return v


class UserOAuthProfileComplete(BaseModel):
    """Model for completing user OAuth profile"""
    user_id: str
    user_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, min_length=10, max_length=10)
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and not re.match(r'^\d{10}$', v):
            raise ValueError('Phone must be exactly 10 digits')
        return v


# Merchant Models
class MerchantCreate(BaseModel):
    """Model for creating a new merchant"""
    store_name: str = Field(..., min_length=1, max_length=100)
    phone: str = Field(..., min_length=10, max_length=10)
    password: str = Field(..., min_length=6, max_length=72)
    
    @validator('phone')
    def validate_phone(cls, v):
        if not re.match(r'^\d{10}$', v):
            raise ValueError('Phone must be exactly 10 digits')
        return v


class MerchantLogin(BaseModel):
    """Model for merchant login"""
    phone: str
    password: str


class MerchantResponse(BaseModel):
    """Model for merchant response"""
    id: str
    store_name: str
    phone: str
    created_at: Optional[datetime] = None


# User Models
class UserCreate(BaseModel):
    """Model for creating a new user"""
    user_name: str = Field(..., min_length=1, max_length=100)
    user_passw: str = Field(..., min_length=6, max_length=72)


class UserLogin(BaseModel):
    """Model for user login"""
    user_id: str
    user_passw: str


class UserResponse(BaseModel):
    """Model for user response"""
    id: str
    user_name: str
    created_at: Optional[datetime] = None


# Merchant-User Link Models
class MerchantUserLink(BaseModel):
    """Model for linking merchant and user"""
    merchant_id: str
    user_id: str
    pin: str = Field(..., min_length=4, max_length=6)
    
    @validator('pin')
    def validate_pin(cls, v):
        if not re.match(r'^\d{4,6}$', v):
            raise ValueError('PIN must be 4-6 digits')
        return v


class MerchantUserLinkResponse(BaseModel):
    """Model for merchant-user link response"""
    id: int
    merchant_id: str
    user_id: str
    balance: float
    created_at: Optional[datetime] = None


# Transaction Models
class AddBalance(BaseModel):
    """Model for adding balance"""
    merchant_id: str
    user_id: str
    amount: float = Field(..., gt=0)
    pin: Optional[str] = Field(None, min_length=4, max_length=6)
    
    @validator('pin')
    def validate_pin(cls, v):
        if v and not re.match(r'^\d{4,6}$', v):
            raise ValueError('PIN must be 4-6 digits')
        return v


class ProcessTransaction(BaseModel):
    """Model for processing a transaction"""
    merchant_id: str
    user_id: str
    amount: float = Field(..., gt=0)
    pin: str = Field(..., min_length=4, max_length=6)


class TransactionResponse(BaseModel):
    """Model for transaction response"""
    id: int
    merchant_id: str
    user_id: str
    amount: float
    transaction_type: str
    balance_after: float
    created_at: Optional[datetime] = None


class BalanceRequest(BaseModel):
    """Model for balance addition request"""
    merchant_id: str
    user_id: str
    amount: float = Field(..., gt=0)
    pin: str = Field(..., min_length=4, max_length=6)
    
    @validator('pin')
    def validate_pin(cls, v):
        if not re.match(r'^\d{4,6}$', v):
            raise ValueError('PIN must be 4-6 digits')
        return v


class LinkRequest(BaseModel):
    """Model for merchant-user link request"""
    merchant_id: str
    user_id: str
    pin: str = Field(..., min_length=4, max_length=6)
    
    @validator('pin')
    def validate_pin(cls, v):
        if not re.match(r'^\d{4,6}$', v):
            raise ValueError('PIN must be 4-6 digits')
        return v


# Token Models
class Token(BaseModel):
    """Model for JWT token"""
    access_token: str
    token_type: str


class TokenData(BaseModel):
    """Model for token data"""
    id: Optional[str] = None
    user_type: Optional[str] = None  # 'merchant' or 'user'
