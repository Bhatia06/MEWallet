from fastapi import APIRouter, HTTPException, status, Request, Depends
from database import get_supabase_client
from models import GoogleOAuthLogin, MerchantOAuthProfileComplete, UserOAuthProfileComplete
from utils import generate_merchant_id, generate_user_id, create_access_token
from config import get_settings
from google.oauth2 import id_token
from google.auth.transport import requests
from datetime import timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
from auth_middleware import get_current_user

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/oauth", tags=["OAuth"])

# Get settings
settings = get_settings()
GOOGLE_CLIENT_ID = settings.GOOGLE_CLIENT_ID


@router.post("/google", response_model=dict)
@limiter.limit("10/minute")
async def google_oauth_login(request: Request, oauth_data: GoogleOAuthLogin):
    """Login or register using Google OAuth"""
    try:
        # Verify Google ID token
        if not GOOGLE_CLIENT_ID:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Google OAuth not configured"
            )
        
        try:
            # Verify the token with Google
            idinfo = id_token.verify_oauth2_token(
                oauth_data.id_token, 
                requests.Request(), 
                GOOGLE_CLIENT_ID
            )
            
            # Get user info from token
            google_email = idinfo.get('email')
            google_name = idinfo.get('name')
            google_id = idinfo.get('sub')
            
            if not google_email or not google_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid Google token"
                )
                
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token"
            )
        
        supabase = get_supabase_client()
        
        # Handle user OAuth
        if oauth_data.user_type == "user":
            # First check if user exists with this Google email
            result = supabase.table("users").select("*").eq("google_email", google_email).execute()
            
            if result.data:
                # User exists with this email
                user_data = result.data[0]
                
                # Update google_id if not already set (linking OAuth to existing account)
                if not user_data.get("google_id"):
                    supabase.table("users").update({
                        "google_id": google_id
                    }).eq("id", user_data["id"]).execute()
                
                access_token = create_access_token(
                    data={"sub": user_data["id"], "user_type": "user"},
                    expires_delta=timedelta(minutes=21600)
                )
                
                return {
                    "message": "Login successful",
                    "user_id": user_data["id"],
                    "user_name": user_data["user_name"],
                    "access_token": access_token,
                    "token_type": "bearer",
                    "profile_completed": user_data.get("profile_completed", True)  # Existing users are complete
                }
            else:
                # Check by google_id as fallback
                result = supabase.table("users").select("*").eq("google_id", google_id).execute()
                
                if result.data:
                    # User exists, login
                    user_data = result.data[0]
                    access_token = create_access_token(
                        data={"sub": user_data["id"], "user_type": "user"},
                        expires_delta=timedelta(minutes=21600)
                    )
                    
                    return {
                        "message": "Login successful",
                        "user_id": user_data["id"],
                        "user_name": user_data["user_name"],
                        "access_token": access_token,
                        "token_type": "bearer",
                        "profile_completed": user_data.get("profile_completed", False)
                    }
                
                # New user, create incomplete profile
                user_id = generate_user_id()
                
                # Ensure ID is unique
                while True:
                    check = supabase.table("users").select("*").eq("id", user_id).execute()
                    if not check.data:
                        break
                    user_id = generate_user_id()
                
                # Create user with minimal Google info (profile incomplete)
                result = supabase.table("users").insert({
                    "id": user_id,
                    "user_name": google_name or google_email.split('@')[0],
                    "user_passw": "",  # No password for OAuth users
                    "google_id": google_id,
                    "google_email": google_email,
                    "profile_completed": False  # Needs to complete profile
                }).execute()
                
                if not result.data:
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Failed to create user"
                    )
                
                access_token = create_access_token(
                    data={"sub": user_id, "user_type": "user"},
                    expires_delta=timedelta(minutes=21600)
                )
                
                return {
                    "message": "Registration successful - Complete your profile",
                    "user_id": user_id,
                    "user_name": google_name or google_email.split('@')[0],
                    "google_email": google_email,
                    "access_token": access_token,
                    "token_type": "bearer",
                    "profile_completed": False  # Needs profile completion
                }
        
        # Handle merchant OAuth
        elif oauth_data.user_type == "merchant":
            # First check if merchant exists with this Google email
            result = supabase.table("merchants").select("*").eq("google_email", google_email).execute()
            
            if result.data:
                # Merchant exists with this email
                merchant_data = result.data[0]
                
                # Update google_id if not already set (linking OAuth to existing account)
                if not merchant_data.get("google_id"):
                    supabase.table("merchants").update({
                        "google_id": google_id
                    }).eq("id", merchant_data["id"]).execute()
                
                access_token = create_access_token(
                    data={"sub": merchant_data["id"], "user_type": "merchant"},
                    expires_delta=timedelta(minutes=21600)
                )
                
                return {
                    "message": "Login successful",
                    "merchant_id": merchant_data["id"],
                    "store_name": merchant_data["store_name"],
                    "access_token": access_token,
                    "token_type": "bearer",
                    "profile_completed": merchant_data.get("profile_completed", True)  # Existing merchants are complete
                }
            
            # Check by google_id as fallback
            result = supabase.table("merchants").select("*").eq("google_id", google_id).execute()
            
            if result.data:
                # Merchant exists, login
                merchant_data = result.data[0]
                access_token = create_access_token(
                    data={"sub": merchant_data["id"], "user_type": "merchant"},
                    expires_delta=timedelta(minutes=21600)
                )
                
                return {
                    "message": "Login successful",
                    "merchant_id": merchant_data["id"],
                    "store_name": merchant_data["store_name"],
                    "access_token": access_token,
                    "token_type": "bearer",
                    "profile_completed": merchant_data.get("profile_completed", False)
                }
            
            # New merchant, create incomplete profile
            merchant_id = generate_merchant_id()
            
            # Ensure ID is unique
            while True:
                check = supabase.table("merchants").select("*").eq("id", merchant_id).execute()
                if not check.data:
                    break
                merchant_id = generate_merchant_id()
            
            # Create merchant with minimal Google info (profile incomplete)
            result = supabase.table("merchants").insert({
                "id": merchant_id,
                "store_name": "",  # Will be filled in profile completion
                "owner_name": google_name,  # Prefilled from OAuth
                "phone": None,  # No phone for OAuth merchants initially
                "password": "",  # No password for OAuth merchants
                "google_id": google_id,
                "google_email": google_email,
                "profile_completed": False  # Needs to complete profile
            }).execute()
            
            if not result.data:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to create merchant"
                )
            
            access_token = create_access_token(
                data={"sub": merchant_id, "user_type": "merchant"},
                expires_delta=timedelta(minutes=21600)
            )
            
            return {
                "message": "Registration successful - Complete your profile",
                "merchant_id": merchant_id,
                "owner_name": google_name,
                "google_email": google_email,
                "access_token": access_token,
                "token_type": "bearer",
                "profile_completed": False  # Needs profile completion
            }
        
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user type"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/merchant/complete-profile", response_model=dict)
@limiter.limit("10/minute")
async def complete_merchant_profile(request: Request, profile_data: MerchantOAuthProfileComplete, current_user: dict = Depends(get_current_user)):
    """Complete merchant OAuth profile with store details"""
    try:
        # Verify merchant can only complete their own profile
        from auth_middleware import verify_resource_ownership
        verify_resource_ownership(current_user, profile_data.merchant_id)
        
        supabase = get_supabase_client()
        
        # Validate phone is provided
        if not profile_data.phone or len(profile_data.phone.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Phone number is required"
            )
        
        # Update merchant profile
        result = supabase.table("merchants").update({
            "store_name": profile_data.store_name,
            "owner_name": profile_data.owner_name,
            "phone": profile_data.phone.strip(),
            "store_address": profile_data.store_address or "",
            "profile_completed": True
        }).eq("id", profile_data.merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        merchant_data = result.data[0]
        
        return {
            "message": "Profile completed successfully",
            "merchant_id": merchant_data["id"],
            "store_name": merchant_data["store_name"],
            "profile_completed": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/user/complete-profile", response_model=dict)
@limiter.limit("10/minute")
async def complete_user_profile(request: Request, profile_data: UserOAuthProfileComplete, current_user: dict = Depends(get_current_user)):
    """Complete user OAuth profile"""
    try:
        # Verify user can only complete their own profile
        from auth_middleware import verify_resource_ownership
        verify_resource_ownership(current_user, profile_data.user_id)
        
        supabase = get_supabase_client()
        
        # Validate phone is provided
        if not profile_data.phone or len(profile_data.phone.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Phone number is required"
            )
        
        # Hash the PIN
        from utils import hash_password
        hashed_pin = hash_password(profile_data.pin)
        
        # Update user profile with phone and PIN
        result = supabase.table("users").update({
            "user_name": profile_data.user_name,
            "phone": profile_data.phone.strip(),
            "pin": hashed_pin,
            "profile_completed": True
        }).eq("id", profile_data.user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        user_data = result.data[0]
        
        return {
            "message": "Profile completed successfully",
            "user_id": user_data["id"],
            "user_name": user_data["user_name"],
            "profile_completed": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
