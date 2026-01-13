from fastapi import APIRouter, HTTPException, status, Depends, Request
from core.database import get_supabase_client
from core.models import MerchantCreate, MerchantLogin, MerchantResponse, Token
from core.utils import hash_password, verify_password, generate_merchant_id, create_access_token
from middleware.auth_middleware import get_current_user, verify_resource_ownership
from datetime import timedelta, datetime
from slowapi import Limiter
from slowapi.util import get_remote_address
from google.oauth2 import id_token
from google.auth.transport import requests
from core.config import get_settings
from pydantic import BaseModel
from typing import Optional

settings = get_settings()
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/merchant", tags=["Merchant"])


# Pydantic models for reminders
class ReminderCreate(BaseModel):
    user_id: str
    link_id: int
    message: str
    reminder_date: str  # ISO format datetime string


class ReminderUpdate(BaseModel):
    message: Optional[str] = None
    reminder_date: Optional[str] = None
    status: Optional[str] = None


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
            "password": hashed_password,
            "profile_completed": True  # Profile is complete during registration
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
        password_value = merchant_data.get("password")
        has_password = bool(password_value and password_value.strip())
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
        
        # Get current merchant data to check existing fields
        current_merchant_data = supabase.table("merchants").select("store_name, phone").eq("id", merchant_id).execute()
        if not current_merchant_data.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        existing_merchant = current_merchant_data.data[0]
        
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
        
        # Check if profile should be marked as completed
        # Profile is complete if both store_name and phone are present
        final_store_name = update_data.get("store_name", existing_merchant.get("store_name"))
        final_phone = update_data.get("phone", existing_merchant.get("phone"))
        
        if final_store_name and final_phone:
            update_data["profile_completed"] = True
        
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


@router.post("/reminders/create", response_model=dict)
async def create_reminder(reminder: ReminderCreate, current_user: dict = Depends(get_current_user)):
    """Create a payment reminder for a user with negative balance"""
    try:
        merchant_id = current_user.get("sub")
        
        print(f"[REMINDER CREATE] Received request:")
        print(f"  merchant_id: {merchant_id}")
        print(f"  user_id: {reminder.user_id}")
        print(f"  link_id: {reminder.link_id}")
        print(f"  message: {reminder.message}")
        print(f"  reminder_date: {reminder.reminder_date}")
        
        if not merchant_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication"
            )
        
        # Validate input data
        if not reminder.user_id or not reminder.message or not reminder.link_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing required fields: user_id, link_id, or message"
            )
        
        supabase = get_supabase_client()
        
        # Verify the link exists and belongs to this merchant
        link_result = supabase.table("merchant_user_links").select(
            "*, users(user_name)"
        ).eq("id", reminder.link_id).eq("merchant_id", merchant_id).execute()
        
        if not link_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Link not found or unauthorized. Link ID: {reminder.link_id}"
            )
        
        link_data = link_result.data[0]
        
        # Verify user has negative balance
        if link_data["balance"] >= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Can only set reminders for users with negative balance"
            )
        
        # Verify user_id matches the link
        if link_data["user_id"] != reminder.user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User ID does not match the link"
            )
        
        # Parse and validate reminder date
        try:
            reminder_datetime = datetime.fromisoformat(reminder.reminder_date.replace('Z', '+00:00'))
            if reminder_datetime <= datetime.now(reminder_datetime.tzinfo):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Reminder date must be in the future"
                )
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use ISO format"
            )
        
        # Create reminder
        result = supabase.table("reminders").insert({
            "merchant_id": merchant_id,
            "user_id": reminder.user_id,
            "link_id": reminder.link_id,
            "message": reminder.message,
            "reminder_date": reminder.reminder_date,
            "status": "active"
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create reminder"
            )
        
        created_reminder = result.data[0]
        
        # Send WebSocket notification to user
        from core.websocket_manager import manager
        await manager.broadcast_reminder_to_user(
            user_id=reminder.user_id,
            reminder_data={
                "id": created_reminder["id"],
                "merchant_id": merchant_id,
                "store_name": link_data.get("store_name", "Store"),
                "balance": link_data["balance"],
                "message": created_reminder["message"],
                "reminder_date": created_reminder["reminder_date"],
                "type": "payment_reminder"
            }
        )
        
        return {
            "message": "Reminder created successfully",
            "reminder": created_reminder
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/reminders/{merchant_id}", response_model=list)
async def get_merchant_reminders(merchant_id: str, current_user: dict = Depends(get_current_user)):
    """Get all reminders created by a merchant"""
    try:
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        result = supabase.table("reminders").select(
            "*, users(user_name), merchant_user_links(store_name, balance)"
        ).eq("merchant_id", merchant_id).order("reminder_date", desc=False).execute()
        
        if not result.data:
            return []
        
        # Format response
        reminders = []
        for reminder in result.data:
            reminders.append({
                "id": reminder["id"],
                "user_id": reminder["user_id"],
                "user_name": reminder["users"]["user_name"] if reminder.get("users") else "Unknown",
                "link_id": reminder["link_id"],
                "store_name": reminder["merchant_user_links"]["store_name"] if reminder.get("merchant_user_links") else None,
                "balance": reminder["merchant_user_links"]["balance"] if reminder.get("merchant_user_links") else 0,
                "message": reminder["message"],
                "reminder_date": reminder["reminder_date"],
                "status": reminder["status"],
                "created_at": reminder["created_at"]
            })
        
        return reminders
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.put("/reminders/{reminder_id}", response_model=dict)
async def update_reminder(reminder_id: int, reminder_update: ReminderUpdate, current_user: dict = Depends(get_current_user)):
    """Update a reminder"""
    try:
        merchant_id = current_user.get("sub")
        supabase = get_supabase_client()
        
        # Verify reminder belongs to merchant
        check_result = supabase.table("reminders").select("*").eq("id", reminder_id).eq("merchant_id", merchant_id).execute()
        
        if not check_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Reminder not found or unauthorized"
            )
        
        update_data = {}
        
        if reminder_update.message is not None:
            update_data["message"] = reminder_update.message
        
        if reminder_update.reminder_date is not None:
            try:
                reminder_datetime = datetime.fromisoformat(reminder_update.reminder_date.replace('Z', '+00:00'))
                if reminder_datetime <= datetime.now(reminder_datetime.tzinfo):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Reminder date must be in the future"
                    )
                update_data["reminder_date"] = reminder_update.reminder_date
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid date format. Use ISO format"
                )
        
        if reminder_update.status is not None:
            if reminder_update.status not in ["active", "dismissed", "expired"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Status must be 'active', 'dismissed', or 'expired'"
                )
            update_data["status"] = reminder_update.status
        
        if not update_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No valid fields to update"
            )
        
        update_data["updated_at"] = datetime.utcnow().isoformat()
        
        result = supabase.table("reminders").update(update_data).eq("id", reminder_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Reminder not found"
            )
        
        return {
            "message": "Reminder updated successfully",
            "reminder": result.data[0]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.delete("/reminders/{reminder_id}", response_model=dict)
async def delete_reminder(reminder_id: int, current_user: dict = Depends(get_current_user)):
    """Delete a reminder"""
    try:
        merchant_id = current_user.get("sub")
        supabase = get_supabase_client()
        
        # Verify reminder belongs to merchant
        check_result = supabase.table("reminders").select("*").eq("id", reminder_id).eq("merchant_id", merchant_id).execute()
        
        if not check_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Reminder not found or unauthorized"
            )
        
        result = supabase.table("reminders").delete().eq("id", reminder_id).execute()
        
        return {
            "message": "Reminder deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
