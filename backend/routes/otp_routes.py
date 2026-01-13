from fastapi import APIRouter, HTTPException, status, Request
from pydantic import BaseModel
from core.database import get_supabase_client
import requests
import random
import os
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
from core.config import get_settings

settings = get_settings()
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/otp", tags=["OTP"])

SMSINDIAHUB_API_KEY = os.getenv("SMSINDIAHUB_API_KEY")
SMSINDIAHUB_SENDER_ID = os.getenv("SMSINDIAHUB_SENDER_ID")
SMSINDIAHUB_GATEWAY_ID = os.getenv("SMSINDIAHUB_GATEWAY_ID")

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
        
        # Use the exact template format from SMSINDIAHUB example
        # Note: This template must be registered and approved in your SMSINDIAHUB account
        message = f"Welcome to the xyz powered by SMSINDIAHUB. Your OTP for registration is {otp}"
        
        # Send OTP via SMSINDIAHUB API
        api_url = "http://cloud.smsindiahub.in/vendorsms/pushsms.aspx"
        params = {
            "APIKey": SMSINDIAHUB_API_KEY,
            "msisdn": phone,
            "sid": SMSINDIAHUB_SENDER_ID,
            "msg": message,
            "fl": "0",
            "gwid": SMSINDIAHUB_GATEWAY_ID
        }
        
        try:
            response = requests.get(api_url, params=params, timeout=10)
            
            # Log response for debugging
            print(f"SMSINDIAHUB Response: {response.text}")
            
            # Parse JSON response
            try:
                response_data = response.json()
                error_code = response_data.get("ErrorCode", "")
                error_message = response_data.get("ErrorMessage", "")
                
                # Check if ErrorCode is "000" (success)
                if error_code != "000":
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail=f"OTP error: {error_message}"
                    )
            except ValueError:
                # If response is not JSON, check text for errors
                response_text = response.text.strip().lower()
                if "error" in response_text or "invalid" in response_text or "fail" in response_text:
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail=f"OTP error: {response.text}"
                    )
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to send OTP: {str(e)}"
            )
        
        expiry_time = datetime.now() + timedelta(minutes=5)
        otp_storage[phone] = {
            "otp": otp,
            "expiry": expiry_time,
            "attempts": 0
        }
        
        return {
            "message": "OTP sent successfully",
            "phone": phone,
            "expires_in": 300
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
