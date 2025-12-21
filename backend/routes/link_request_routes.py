from fastapi import APIRouter, HTTPException, status, BackgroundTasks, Depends, Request
from core.database import get_supabase_client
from core.models import LinkRequest
from core.utils import hash_password
from middleware.auth_middleware import get_current_user
from datetime import datetime
from slowapi import Limiter
from slowapi.util import get_remote_address
import asyncio

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/link-requests", tags=["Link Requests"])


async def delete_link_request_after_delay(request_id: int, delay_seconds: int = 10):
    """Delete a link request after specified delay"""
    await asyncio.sleep(delay_seconds)
    try:
        supabase = get_supabase_client()
        supabase.table("link_requests").delete().eq("id", request_id).execute()
        print(f"Deleted link request {request_id} after {delay_seconds} seconds")
    except Exception as e:
        print(f"Error deleting link request {request_id}: {str(e)}")


@router.post("/create", response_model=dict, status_code=status.HTTP_201_CREATED)
@limiter.limit("15/minute")
async def create_link_request(request: Request, request_data: LinkRequest, current_user: dict = Depends(get_current_user)):
    """Create a link request from user to merchant"""
    try:
        supabase = get_supabase_client()
        
        # Verify merchant exists
        merchant = supabase.table("merchants").select("*").eq("id", request_data.merchant_id).execute()
        if not merchant.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        # Verify user exists
        user = supabase.table("users").select("*").eq("id", request_data.user_id).execute()
        if not user.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Check if already linked
        existing_link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", request_data.merchant_id
        ).eq("user_id", request_data.user_id).execute()
        
        if existing_link.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You are already linked with this merchant"
            )
        
        # Check if there's already a pending request
        existing_request = supabase.table("link_requests").select("*").eq(
            "merchant_id", request_data.merchant_id
        ).eq("user_id", request_data.user_id).eq("status", "pending").execute()
        
        if existing_request.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You already have a pending link request with this merchant"
            )
        
        # Create link request
        result = supabase.table("link_requests").insert({
            "merchant_id": request_data.merchant_id,
            "user_id": request_data.user_id,
            "pin": request_data.pin,
            "status": "pending"
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create link request"
            )
        
        return {
            "message": "Link request sent successfully",
            "request_id": result.data[0]["id"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/merchant/{merchant_id}", response_model=list)
async def get_merchant_link_requests(merchant_id: str, current_user: dict = Depends(get_current_user)):
    """Get all pending link requests for a merchant"""
    try:
        # Verify merchant can only access their own requests
        from middleware.auth_middleware import verify_resource_ownership
        verify_resource_ownership(current_user, merchant_id)
        
        supabase = get_supabase_client()
        
        result = supabase.table("link_requests").select(
            "*, users(user_name)"
        ).eq("merchant_id", merchant_id).eq("status", "pending").execute()
        
        if not result.data:
            return []
        
        requests = []
        for req in result.data:
            requests.append({
                "request_id": req["id"],
                "merchant_id": req["merchant_id"],
                "user_id": req["user_id"],
                "user_name": req["users"]["user_name"] if req.get("users") else "Unknown",
                "pin": req["pin"],
                "status": req["status"],
                "created_at": req["created_at"],
                "request_type": "link"
            })
        
        return requests
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/accept/{request_id}", response_model=dict)
@limiter.limit("20/minute")
async def accept_link_request(request: Request, request_id: int, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    """Accept a link request and create the link"""
    try:
        supabase = get_supabase_client()
        
        # Get the request
        request = supabase.table("link_requests").select("*").eq("id", request_id).execute()
        
        if not request.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found"
            )
        
        req_data = request.data[0]
        
        if req_data["status"] != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Request has already been processed"
            )
        
        # Check if link already exists (race condition check)
        existing_link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", req_data["merchant_id"]
        ).eq("user_id", req_data["user_id"]).execute()
        
        if existing_link.data:
            # Update request status and schedule deletion
            supabase.table("link_requests").update({
                "status": "accepted"
            }).eq("id", request_id).execute()
            
            background_tasks.add_task(delete_link_request_after_delay, request_id, 10)
            
            return {
                "message": "Link already exists",
                "user_id": req_data["user_id"]
            }
        
        # Create new link with zero balance
        supabase.table("merchant_user_links").insert({
            "merchant_id": req_data["merchant_id"],
            "user_id": req_data["user_id"],
            "pin": hash_password(req_data["pin"]),
            "balance": 0.0
        }).execute()
        
        # Update request status
        supabase.table("link_requests").update({
            "status": "accepted"
        }).eq("id", request_id).execute()
        
        # Schedule deletion after 10 seconds
        background_tasks.add_task(delete_link_request_after_delay, request_id, 10)
        
        return {
            "message": "Link request accepted successfully",
            "user_id": req_data["user_id"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/reject/{request_id}", response_model=dict)
@limiter.limit("20/minute")
async def reject_link_request(request: Request, request_id: int, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    """Reject a link request"""
    try:
        supabase = get_supabase_client()
        
        # Get the request
        request = supabase.table("link_requests").select("*").eq("id", request_id).execute()
        
        if not request.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found"
            )
        
        if request.data[0]["status"] != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Request has already been processed"
            )
        
        # Update request status
        supabase.table("link_requests").update({
            "status": "rejected"
        }).eq("id", request_id).execute()
        
        # Schedule deletion after 10 seconds
        background_tasks.add_task(delete_link_request_after_delay, request_id, 10)
        
        return {
            "message": "Link request rejected",
            "user_id": request.data[0]["user_id"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
