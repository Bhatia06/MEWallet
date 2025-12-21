from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from slowapi import Limiter
from slowapi.util import get_remote_address
from database import get_supabase_client

router = APIRouter(prefix="/check", tags=["Validation"])
limiter = Limiter(key_func=get_remote_address)

class PhoneCheckRequest(BaseModel):
    phone: str

class EmailCheckRequest(BaseModel):
    email: str

@router.post("/phone-exists")
@limiter.limit("10/minute")
async def check_phone_exists(request: Request, phone_request: PhoneCheckRequest):
    """Check if phone number exists in users or merchants table"""
    try:
        supabase = get_supabase_client()
        
        # Check in users table
        user_result = supabase.table("users").select("id").eq("phone", phone_request.phone).execute()
        
        # Check in merchants table
        merchant_result = supabase.table("merchants").select("id").eq("phone", phone_request.phone).execute()
        
        if user_result.data and len(user_result.data) > 0:
            return {
                "exists": True,
                "user_type": "user",
                "message": "Phone number is registered as a user account"
            }
        elif merchant_result.data and len(merchant_result.data) > 0:
            return {
                "exists": True,
                "user_type": "merchant",
                "message": "Phone number is registered as a merchant account"
            }
        else:
            return {
                "exists": False,
                "user_type": None,
                "message": "Phone number is available"
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@router.post("/email-exists")
@limiter.limit("10/minute")
async def check_email_exists(request: Request, email_request: EmailCheckRequest):
    """Check if email exists in users or merchants table (for OAuth)"""
    try:
        supabase = get_supabase_client()
        
        # Check in users table
        user_result = supabase.table("users").select("id, user_name").eq("user_name", email_request.email).execute()
        
        # Check in merchants table  
        merchant_result = supabase.table("merchants").select("id, store_name").eq("store_name", email_request.email).execute()
        
        if user_result.data and len(user_result.data) > 0:
            user_row = user_result.data[0]
            return {
                "exists": True,
                "user_type": "user",
                "user_id": user_row.get('user_id'),
                "user_name": user_row.get('user_name'),
                "message": "Email is registered as a user account"
            }
        elif merchant_result.data and len(merchant_result.data) > 0:
            merchant_row = merchant_result.data[0]
            return {
                "exists": True,
                "user_type": "merchant",
                "merchant_id": merchant_row.get('merchant_id'),
                "store_name": merchant_row.get('store_name'),
                "message": "Email is registered as a merchant account"
            }
        else:
            return {
                "exists": False,
                "user_type": None,
                "message": "Email is available"
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
