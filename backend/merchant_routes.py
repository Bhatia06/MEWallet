from fastapi import APIRouter, HTTPException, status, Depends, Request
from database import get_supabase_client
from models import MerchantCreate, MerchantLogin, MerchantResponse, Token
from utils import hash_password, verify_password, generate_merchant_id, create_access_token
from auth_middleware import get_current_user, verify_resource_ownership
from datetime import timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address

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


@router.get("/profile/{merchant_id}", response_model=dict)
async def get_merchant_profile(merchant_id: str, current_user: dict = Depends(get_current_user)):
    """Get merchant profile"""
    try:
        # Verify merchant can only access their own profile
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        result = supabase.table("merchants").select("id, store_name, phone, created_at").eq("id", merchant_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        return result.data[0]
        
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
