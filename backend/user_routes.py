from fastapi import APIRouter, HTTPException, status, Depends
from database import get_supabase_client
from models import UserCreate, UserCompleteProfile, UserLogin, UserResponse, Token
from utils import hash_password, hash_pin, verify_password, verify_pin, generate_user_id, create_access_token
from auth_middleware import get_current_user, verify_resource_ownership
from datetime import timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/user", tags=["User"])


@router.post("/register", response_model=dict, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register_user(request: Request, user: UserCreate):
    """Register a new user with phone and PIN"""
    try:
        supabase = get_supabase_client()
        
        # Check if phone already exists
        phone_check = supabase.table("users").select("*").eq("phone", user.phone).execute()
        if phone_check.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        # Generate unique user ID
        user_id = generate_user_id()
        
        # Ensure ID is unique
        while True:
            check = supabase.table("users").select("*").eq("id", user_id).execute()
            if not check.data:
                break
            user_id = generate_user_id()
        
        # Hash password and PIN
        hashed_password = hash_password(user.user_passw)
        hashed_pin = hash_pin(user.pin)
        
        # Insert user with phone, PIN, and profile_completed = TRUE
        result = supabase.table("users").insert({
            "id": user_id,
            "user_name": user.user_name,
            "user_passw": hashed_password,
            "phone": user.phone,
            "pin": hashed_pin,
            "profile_completed": True  # Profile is complete since phone and PIN are provided
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user account"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": user_id, "user_type": "user"},
            expires_delta=timedelta(minutes=10080)  # 7 days
        )
        
        return {
            "message": "User registered successfully",
            "user_id": user_id,
            "user_name": user.user_name,
            "access_token": access_token,
            "token_type": "bearer",
            "profile_completed": True
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
async def login_user(request: Request, user: UserLogin):
    """Login user and check profile completion status"""
    try:
        supabase = get_supabase_client()
        
        # Find user by ID
        result = supabase.table("users").select("*").eq("id", user.user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        user_data = result.data[0]
        
        # Verify password
        if not verify_password(user.user_passw, user_data["user_passw"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # Check profile completion status
        profile_completed = user_data.get("profile_completed", False)
        needs_phone = user_data.get("phone") is None
        needs_pin = user_data.get("pin") is None
        
        # Create access token
        access_token = create_access_token(
            data={"sub": user_data["id"], "user_type": "user"},
            expires_delta=timedelta(minutes=10080)  # 7 days
        )
        
        return {
            "message": "Login successful",
            "user_id": user_data["id"],
            "user_name": user_data["user_name"],
            "access_token": access_token,
            "token_type": "bearer",
            "profile_completed": profile_completed,
            "needs_phone": needs_phone,
            "needs_pin": needs_pin
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/complete-profile", response_model=dict)
@limiter.limit("10/minute")
async def complete_user_profile(request: Request, profile_data: UserCompleteProfile, current_user: dict = Depends(get_current_user)):
    """Complete user profile with phone and PIN (for existing users)"""
    try:
        supabase = get_supabase_client()
        
        # Verify user_id matches current user
        if profile_data.user_id != current_user["sub"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot complete profile for another user"
            )
        
        # Check if phone already exists (for other users)
        phone_check = supabase.table("users").select("*").eq("phone", profile_data.phone).execute()
        if phone_check.data:
            existing_user = phone_check.data[0]
            if existing_user["id"] != profile_data.user_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered"
                )
        
        # Hash PIN
        hashed_pin = hash_pin(profile_data.pin)
        
        # Update user profile
        result = supabase.table("users").update({
            "phone": profile_data.phone,
            "pin": hashed_pin,
            "profile_completed": True
        }).eq("id", profile_data.user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile"
            )
        
        return {
            "message": "Profile completed successfully",
            "user_id": profile_data.user_id,
            "profile_completed": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/profile/{user_id}", response_model=dict)
async def get_user_profile(user_id: str, current_user: dict = Depends(get_current_user)):
    """Get user profile"""
    try:
        # Verify user can only access their own profile
        verify_resource_ownership(current_user, user_id)
        
        supabase = get_supabase_client()
        
        result = supabase.table("users").select("id, user_name, created_at").eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return result.data[0]
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/linked-merchants/{user_id}", response_model=list)
async def get_linked_merchants(user_id: str, current_user: dict = Depends(get_current_user)):
    """Get all merchants linked to a user"""
    try:
        # Verify user can only access their own links
        verify_resource_ownership(current_user, user_id)
        
        supabase = get_supabase_client()
        
        # Get all merchant-user links
        result = supabase.table("merchant_user_links").select(
            "*, merchants(store_name, phone)"
        ).eq("user_id", user_id).execute()
        
        if not result.data:
            return []
        
        # Format response
        linked_merchants = []
        for link in result.data:
            linked_merchants.append({
                "link_id": link["id"],
                "merchant_id": link["merchant_id"],
                "user_id": link["user_id"],
                "store_name": link["merchants"]["store_name"] if link.get("merchants") else "Unknown",
                "balance": link["balance"],
                "created_at": link["created_at"]
            })
        
        return linked_merchants
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
