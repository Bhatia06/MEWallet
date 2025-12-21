from fastapi import APIRouter, HTTPException, status, Depends, Request
from core.database import get_supabase_client
from core.models import MerchantCreate, MerchantLogin, MerchantResponse, Token
from core.utils import hash_password, verify_password, generate_merchant_id, create_access_token
from middleware.auth_middleware import get_current_user, verify_resource_ownership
from datetime import timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
from google.oauth2 import id_token
from google.auth.transport import requests
from core.config import get_settings

settings = get_settings()
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/merchant", tags=["Merchant"])


@router.post("/register", response_model=dict, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register_merchant(request: Request, merchant: MerchantCreate):
    """Register a new merchant"""
    try:
        supabase = get_supabase_client()
        
        # Check if phone already exists
        existing = supabase.table("merchants").select("*").eq("phone", merchant.phone).execute()
        if existing.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        # Generate unique merchant ID
        merchant_id = generate_merchant_id()
        
        # Ensure ID is unique
        while True:
            check = supabase.table("merchants").select("*").eq("id", merchant_id).execute()
            if not check.data:
                break
            merchant_id = generate_merchant_id()
        
        # Hash password
        hashed_password = hash_password(merchant.password)
        
        # Insert merchant
        result = supabase.table("merchants").insert({
            "id": merchant_id,
            "store_name": merchant.store_name,
            "phone": merchant.phone,
            "password": hashed_password
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create merchant account"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": merchant_id, "user_type": "merchant"},
            expires_delta=timedelta(minutes=30)
        )
        
        return {
            "message": "Merchant registered successfully",
            "merchant_id": merchant_id,
            "store_name": merchant.store_name,
            "access_token": access_token,
            "token_type": "bearer"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/login", response_model=dict)
@limiter.limit("10/minute")
async def login_merchant(request: Request, merchant: MerchantLogin):
    """Login merchant"""
    try:
        supabase = get_supabase_client()
        
        # Find merchant by phone
        result = supabase.table("merchants").select("*").eq("phone", merchant.phone).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        merchant_data = result.data[0]
        
        # Verify password
        if not verify_password(merchant.password, merchant_data["password"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": merchant_data["id"], "user_type": "merchant"},
            expires_delta=timedelta(minutes=30)
        )
        
        return {
            "message": "Login successful",
            "merchant_id": merchant_data["id"],
            "store_name": merchant_data["store_name"],
            "access_token": access_token,
            "token_type": "bearer"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/linked-users/{merchant_id}", response_model=list)
async def get_linked_users(merchant_id: str, current_user: dict = Depends(get_current_user)):
    """Get all users linked to a merchant"""
    try:
        # Verify merchant can only access their own links
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        # Get all merchant-user links
        result = supabase.table("merchant_user_links").select(
            "*, users(user_name)"
        ).eq("merchant_id", merchant_id).execute()
        
        if not result.data:
            return []
        
        # Format response
        linked_users = []
        for link in result.data:
            linked_users.append({
                "link_id": link["id"],
                "merchant_id": link["merchant_id"],
                "user_id": link["user_id"],
                "user_name": link["users"]["user_name"] if link.get("users") else "Unknown",
                "balance": link["balance"],
                "created_at": link["created_at"]
            })
        
        return linked_users
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/profile/{merchant_id}", response_model=dict)
async def get_merchant_profile_details(merchant_id: str, current_user: dict = Depends(get_current_user)):
    """Get detailed merchant profile"""
    try:
        verify_resource_ownership(current_user, merchant_id)
        supabase = get_supabase_client()
        
        result = supabase.table("merchants").select("id, store_name, phone, store_address, google_id, google_email, password, created_at").eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        merchant_data = result.data[0]
        # Don't send password hash, just indicate if it exists
        has_password = bool(merchant_data.get("password") and merchant_data.get("password").strip())
        merchant_data["has_password"] = has_password
        del merchant_data["password"]  # Remove password hash from response
        
        return merchant_data
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.put("/profile/{merchant_id}", response_model=dict)
async def update_merchant_profile(merchant_id: str, profile_data: dict, current_user: dict = Depends(get_current_user)):
    """Update merchant profile"""
    try:
        verify_resource_ownership(current_user, merchant_id)
        supabase = get_supabase_client()
        
        update_data = {}
        if "store_name" in profile_data:
            update_data["store_name"] = profile_data["store_name"]
        if "phone" in profile_data:
            update_data["phone"] = profile_data["phone"]
        if "store_address" in profile_data:
            update_data["store_address"] = profile_data["store_address"]
        
        if not update_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No valid fields to update"
            )
        
        result = supabase.table("merchants").update(update_data).eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        return {
            "message": "Profile updated successfully",
            "merchant": result.data[0]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/link-google", response_model=dict)
async def link_google_to_merchant(link_data: dict, current_user: dict = Depends(get_current_user)):
    """Link Google account to existing merchant"""
    try:
        merchant_id = link_data.get("merchant_id")
        id_token_str = link_data.get("id_token")
        
        if not merchant_id or not id_token_str:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="merchant_id and id_token are required"
            )
        
        verify_resource_ownership(current_user, merchant_id)
        
        # Verify Google ID token
        try:
            google_data = id_token.verify_oauth2_token(
                id_token_str, requests.Request(), settings.GOOGLE_CLIENT_ID
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Google token: {str(e)}"
            )
        
        google_id = google_data.get("sub")
        google_email = google_data.get("email")
        
        supabase = get_supabase_client()
        
        # Check if Google ID is already linked to another account
        existing = supabase.table("merchants").select("*").eq("google_id", google_id).execute()
        if existing.data and existing.data[0]["id"] != merchant_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This Google account is already linked to another merchant"
            )
        
        # Link Google account
        result = supabase.table("merchants").update({
            "google_id": google_id,
            "google_email": google_email
        }).eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        return {
            "message": "Google account linked successfully",
            "google_email": google_email
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/set-password", response_model=dict)
async def set_merchant_password(password_data: dict, current_user: dict = Depends(get_current_user)):
    """Set or update merchant password for manual login"""
    try:
        merchant_id = password_data.get("merchant_id")
        password = password_data.get("password")
        
        if not merchant_id or not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="merchant_id and password are required"
            )
        
        if len(password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be at least 6 characters"
            )
        
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        # Hash the password
        from core.utils import hash_password
        hashed_password = hash_password(password)
        
        # Update merchant password
        result = supabase.table("merchants").update({
            "password": hashed_password
        }).eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        return {
            "message": "Password set successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )

@router.post("/update-password", response_model=dict)
async def update_merchant_password(password_data: dict, current_user: dict = Depends(get_current_user)):
    """Update merchant password with old password verification"""
    try:
        merchant_id = password_data.get("merchant_id")
        old_password = password_data.get("old_password")
        new_password = password_data.get("new_password")
        
        if not merchant_id or not old_password or not new_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="merchant_id, old_password, and new_password are required"
            )
        
        if len(new_password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password must be at least 6 characters"
            )
        
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        # Get current merchant data
        result = supabase.table("merchants").select("password").eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        current_password_hash = result.data[0].get("password")
        
        # Verify old password
        from core.utils import verify_password
        if not current_password_hash or not verify_password(old_password, current_password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect"
            )
        
        # Hash the new password
        from core.utils import hash_password
        hashed_password = hash_password(new_password)
        
        # Update merchant password
        update_result = supabase.table("merchants").update({
            "password": hashed_password
        }).eq("id", merchant_id).execute()
        
        if not update_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        return {
            "message": "Password updated successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )