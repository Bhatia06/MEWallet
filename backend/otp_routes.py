from fastapi import APIRouter, HTTPException, status, Request
from pydantic import BaseModel
from database import get_supabase_client
import requests
import random
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/otp", tags=["OTP"])

# 2Factor API Configuration
TWOFACTOR_API_KEY = "e0979cba-1c53-11f0-8b17-0200cd936042"

# In-memory OTP storage (for production, use Redis)
otp_storage = {}

class SendOTPRequest(BaseModel):
    phone: str

class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str

def generate_otp():
    """Generate a 6-digit OTP"""
    return str(random.randint(100000, 999999))

@router.post("/send")
@limiter.limit("5/minute")
async def send_otp(request: Request, otp_request: SendOTPRequest):
    """Send OTP to phone number using 2Factor API"""
    try:
        phone = otp_request.phone.strip()
        
        # Validate phone number (basic validation)
        if not phone or len(phone) < 10:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid phone number"
            )
        
        # Generate OTP
        otp = generate_otp()
        
        # Send OTP via 2Factor API
        api_url = f"https://2factor.in/API/V1/{TWOFACTOR_API_KEY}/SMS/{phone}/{otp}/OTP1"
        
        try:
            response = requests.get(api_url, timeout=10)
            response.raise_for_status()
            
            # Check if API request was successful
            response_data = response.json()
            if response_data.get("Status") != "Success":
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to send OTP"
                )
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to send OTP: {str(e)}"
            )
        
        # Store OTP with expiry time (5 minutes)
        expiry_time = datetime.now() + timedelta(minutes=5)
        otp_storage[phone] = {
            "otp": otp,
            "expiry": expiry_time,
            "attempts": 0
        }
        
        return {
            "message": "OTP sent successfully",
            "phone": phone,
            "expires_in": 300  # 5 minutes in seconds
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error sending OTP: {str(e)}"
        )

@router.post("/verify")
@limiter.limit("10/minute")
async def verify_otp(request: Request, verify_request: VerifyOTPRequest):
    """Verify OTP for phone number"""
    try:
        phone = verify_request.phone.strip()
        otp = verify_request.otp.strip()
        
        # Check if OTP exists for this phone
        if phone not in otp_storage:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No OTP found for this phone number. Please request a new OTP."
            )
        
        stored_data = otp_storage[phone]
        
        # Check if OTP has expired
        if datetime.now() > stored_data["expiry"]:
            del otp_storage[phone]
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OTP has expired. Please request a new OTP."
            )
        
        # Check attempts
        if stored_data["attempts"] >= 3:
            del otp_storage[phone]
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many failed attempts. Please request a new OTP."
            )
        
        # Verify OTP
        if stored_data["otp"] != otp:
            stored_data["attempts"] += 1
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid OTP. {3 - stored_data['attempts']} attempts remaining."
            )
        
        # OTP verified successfully - remove from storage
        del otp_storage[phone]
        
        return {
            "message": "OTP verified successfully",
            "phone": phone,
            "verified": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error verifying OTP: {str(e)}"
        )

@router.post("/resend")
@limiter.limit("3/minute")
async def resend_otp(request: Request, otp_request: SendOTPRequest):
    """Resend OTP to phone number"""
    # Clear existing OTP if any
    if otp_request.phone.strip() in otp_storage:
        del otp_storage[otp_request.phone.strip()]
    
    # Send new OTP
    return await send_otp(request, otp_request)
