from fastapi import APIRouter, HTTPException, status, Depends
from core.database import get_supabase_client
from core.models import UserCreate, UserLogin, UserResponse, Token
from core.utils import hash_password, verify_password, generate_user_id, create_access_token
from datetime import timedelta
from middleware.auth_middleware import get_current_user, verify_resource_ownership
from google.oauth2 import id_token
from google.auth.transport import requests
from core.config import get_settings
from pydantic import BaseModel
from typing import Optional

settings = get_settings()

router = APIRouter(prefix="/user", tags=["User"])


@router.post("/register", response_model=dict, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate):
    """Register a new user"""
    try:
        supabase = get_supabase_client()
        
        # Generate unique user ID
        user_id = generate_user_id()
        
        # Ensure ID is unique
        while True:
            check = supabase.table("users").select("*").eq("id", user_id).execute()
            if not check.data:
                break
            user_id = generate_user_id()
        
        # Hash password
        hashed_password = hash_password(user.user_passw)
        
        # Hash PIN
        hashed_pin = hash_password(user.pin)
        
        # Insert user
        result = supabase.table("users").insert({
            "id": user_id,
            "user_name": user.user_name,
            "user_passw": hashed_password,
            "phone": user.phone,
            "pin": hashed_pin,
            "profile_completed": True  # Profile is complete during registration
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user account"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": user_id, "user_type": "user"},
            expires_delta=timedelta(minutes=30)
        )
        
        return {
            "message": "User registered successfully",
            "user_id": user_id,
            "user_name": user.user_name,
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
async def login_user(user: UserLogin):
    """Login user"""
    try:
        supabase = get_supabase_client()
        
        # Find user by phone number
        result = supabase.table("users").select("*").eq("phone", user.phone).execute()
        
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
        
        # Create access token
        access_token = create_access_token(
            data={"sub": user_data["id"], "user_type": "user"},
            expires_delta=timedelta(minutes=30)
        )
        
        return {
            "message": "Login successful",
            "user_id": user_data["id"],
            "user_name": user_data["user_name"],
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


@router.get("/linked-merchants/{user_id}", response_model=list)
async def get_linked_merchants(user_id: str):
    """Get all merchants linked to a user"""
    try:
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


@router.get("/profile/{user_id}", response_model=dict)
async def get_user_profile_details(user_id: str, current_user: dict = Depends(get_current_user)):
    """Get detailed user profile"""
    try:
        verify_resource_ownership(current_user, user_id)
        supabase = get_supabase_client()
        
        result = supabase.table("users").select("id, user_name, phone, dob, google_id, google_email, user_passw, created_at").eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        user_data = result.data[0]
        # Don't send password hash, just indicate if it exists
        password_value = user_data.get("user_passw")
        has_password = bool(password_value and password_value.strip())
        user_data["has_password"] = has_password
        del user_data["user_passw"]  # Remove password hash from response
        
        return user_data
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.put("/profile/{user_id}", response_model=dict)
async def update_user_profile(user_id: str, profile_data: dict, current_user: dict = Depends(get_current_user)):
    """Update user profile"""
    try:
        verify_resource_ownership(current_user, user_id)
        supabase = get_supabase_client()
        
        # Get current user data to check existing fields
        current_user_data = supabase.table("users").select("user_name, phone").eq("id", user_id).execute()
        if not current_user_data.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        existing_user = current_user_data.data[0]
        
        update_data = {}
        if "user_name" in profile_data:
            update_data["user_name"] = profile_data["user_name"]
        if "phone" in profile_data:
            update_data["phone"] = profile_data["phone"]
        if "dob" in profile_data:
            update_data["dob"] = profile_data["dob"]
        
        if not update_data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No valid fields to update"
            )
        
        # Check if profile should be marked as completed
        # Profile is complete if both user_name and phone are present
        final_user_name = update_data.get("user_name", existing_user.get("user_name"))
        final_phone = update_data.get("phone", existing_user.get("phone"))
        
        if final_user_name and final_phone:
            update_data["profile_completed"] = True
        
        result = supabase.table("users").update(update_data).eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return {
            "message": "Profile updated successfully",
            "user": result.data[0]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/link-google", response_model=dict)
async def link_google_to_user(link_data: dict, current_user: dict = Depends(get_current_user)):
    """Link Google account to existing user"""
    try:
        user_id = link_data.get("user_id")
        id_token_str = link_data.get("id_token")
        
        if not user_id or not id_token_str:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="user_id and id_token are required"
            )
        
        verify_resource_ownership(current_user, user_id)
        
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
        existing = supabase.table("users").select("*").eq("google_id", google_id).execute()
        if existing.data and existing.data[0]["id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This Google account is already linked to another user"
            )
        
        # Link Google account
        result = supabase.table("users").update({
            "google_id": google_id,
            "google_email": google_email
        }).eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
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
async def set_user_password(password_data: dict, current_user: dict = Depends(get_current_user)):
    """Set or update user password for manual login"""
    try:
        user_id = password_data.get("user_id")
        password = password_data.get("password")
        
        if not user_id or not password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="user_id and password are required"
            )
        
        if len(password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password must be at least 6 characters"
            )
        
        verify_resource_ownership(current_user, user_id)
        
        supabase = get_supabase_client()
        
        # Hash the password
        hashed_password = hash_password(password)
        
        # Update user password
        result = supabase.table("users").update({
            "user_passw": hashed_password
        }).eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
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
async def update_user_password(password_data: dict, current_user: dict = Depends(get_current_user)):
    """Update user password with old password verification"""
    try:
        user_id = password_data.get("user_id")
        old_password = password_data.get("old_password")
        new_password = password_data.get("new_password")
        
        if not user_id or not old_password or not new_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="user_id, old_password, and new_password are required"
            )
        
        if len(new_password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password must be at least 6 characters"
            )
        
        verify_resource_ownership(current_user, user_id)
        
        supabase = get_supabase_client()
        
        # Get current user data
        result = supabase.table("users").select("user_passw").eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        current_password_hash = result.data[0].get("user_passw")
        
        # Verify old password
        if not current_password_hash or not verify_password(old_password, current_password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current password is incorrect"
            )
        
        # Hash the new password
        hashed_password = hash_password(new_password)
        
        # Update user password
        update_result = supabase.table("users").update({
            "user_passw": hashed_password
        }).eq("id", user_id).execute()
        
        if not update_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
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


@router.delete("/account/{user_id}", response_model=dict)
async def delete_user_account(user_id: str, current_user: dict = Depends(get_current_user)):
    """Delete user account - only if all balances are zero"""
    try:
        verify_resource_ownership(current_user, user_id)
        supabase = get_supabase_client()
        
        # Check all merchant links for non-zero balances
        links = supabase.table("merchant_user_links").select("balance, merchant_id, merchants(store_name)").eq("user_id", user_id).execute()
        
        if links.data:
            non_zero_balances = [link for link in links.data if link["balance"] != 0]
            if non_zero_balances:
                details = []
                for link in non_zero_balances:
                    store_name = link.get("merchants", {}).get("store_name", "Unknown Store") if link.get("merchants") else "Unknown Store"
                    balance = link["balance"]
                    status_msg = f"{store_name}: ₹{abs(balance)} {'owed by you' if balance < 0 else 'credit'}"
                    details.append(status_msg)
                
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Cannot delete account. Please clear all balances first:\n" + "\n".join(details)
                )
        
        # Delete all transactions
        supabase.table("transactions").delete().eq("user_id", user_id).execute()
        
        # Delete all balance requests
        supabase.table("balance_requests").delete().eq("user_id", user_id).execute()
        
        # Delete all link requests
        supabase.table("link_requests").delete().eq("user_id", user_id).execute()
        
        # Delete all merchant-user links
        supabase.table("merchant_user_links").delete().eq("user_id", user_id).execute()
        
        # Delete user
        result = supabase.table("users").delete().eq("id", user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return {
            "message": "Account deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


# Pydantic model for dismissing reminders
class DismissReminder(BaseModel):
    status: str = "dismissed"


@router.get("/notifications/{user_id}", response_model=list)
async def get_user_notifications(user_id: str, current_user: dict = Depends(get_current_user)):
    """Get all active reminders/notifications for a user"""
    try:
        verify_resource_ownership(current_user, user_id)
        
        supabase = get_supabase_client()
        
        print(f"NOTIFICATIONS API: Fetching notifications for user {user_id}")
        
        # Get all active reminders for this user
        # Note: Join with merchants table for store name, not merchant_user_links
        result = supabase.table("reminders").select(
            "*, merchants(store_name)"
        ).eq("user_id", user_id).eq("status", "active").order("reminder_date", desc=False).execute()
        
        print(f"NOTIFICATIONS API: Query result count: {len(result.data) if result.data else 0}")
        if result.data:
            print(f"NOTIFICATIONS API: First reminder: {result.data[0]}")
        
        if not result.data:
            return []
        
        # Get the balance from merchant_user_links separately (only merchant_id and balance exist)
        links_result = supabase.table("merchant_user_links").select(
            "merchant_id, balance"
        ).eq("user_id", user_id).execute()
        
        # Create a lookup dict for balances by merchant_id
        balances = {link["merchant_id"]: link["balance"] 
                   for link in links_result.data} if links_result.data else {}
        
        # Format response
        notifications = []
        for reminder in result.data:
            print(f"NOTIFICATIONS API: Processing reminder {reminder['id']}")
            merchant_id = reminder["merchant_id"]
            
            notifications.append({
                "id": reminder["id"],
                "merchant_id": merchant_id,
                "store_name": reminder["merchants"]["store_name"] if reminder.get("merchants") else "Unknown Store",
                "balance": balances.get(merchant_id, 0),
                "message": reminder["message"],
                "reminder_date": reminder["reminder_date"],
                "status": reminder["status"],
                "created_at": reminder["created_at"],
                "type": "payment_reminder"
            })
        
        print(f"NOTIFICATIONS API: Returning {len(notifications)} notifications")
        return notifications
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"NOTIFICATIONS API ERROR: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.delete("/notifications/{reminder_id}/dismiss", response_model=dict)
async def dismiss_notification(reminder_id: int, current_user: dict = Depends(get_current_user)):
    """Delete/dismiss a notification/reminder"""
    try:
        user_id = current_user.get("sub")
        supabase = get_supabase_client()
        
        # Verify reminder belongs to user
        check_result = supabase.table("reminders").select("*").eq("id", reminder_id).eq("user_id", user_id).execute()
        
        if not check_result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found or unauthorized"
            )
        
        # Delete the reminder
        result = supabase.table("reminders").delete().eq("id", reminder_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found"
            )
        
        # Send WebSocket notification to user
        from core.websocket_manager import manager
        await manager.broadcast_reminder_dismissed_to_user(user_id, reminder_id)
        
        return {
            "message": "Notification deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


