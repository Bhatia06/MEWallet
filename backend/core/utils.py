from passlib.context import CryptContext
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from core.config import get_settings
import secrets
import hashlib

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a password using bcrypt"""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)


def hash_pin(pin: str) -> str:
    """Hash a 4-digit PIN using bcrypt (same as password)"""
    return pwd_context.hash(pin)


def verify_pin(plain_pin: str, hashed_pin: str) -> bool:
    """Verify a PIN against its hash"""
    return pwd_context.verify(plain_pin, hashed_pin)


def generate_merchant_id() -> str:
    """Generate a unique 6-digit merchant ID starting with MR"""
    random_bytes = secrets.token_bytes(3)
    hash_value = hashlib.sha256(random_bytes).hexdigest()[:6].upper()
    return f"MR{hash_value}"


def generate_user_id() -> str:
    """Generate a unique 6-digit user ID starting with UR"""
    random_bytes = secrets.token_bytes(3)
    hash_value = hashlib.sha256(random_bytes).hexdigest()[:6].upper()
    return f"UR{hash_value}"


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_token(token: str) -> Optional[dict]:
    """Verify JWT token and return payload"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None
