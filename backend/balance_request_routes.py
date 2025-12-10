from fastapi import APIRouter, HTTPException, status, BackgroundTasks
from database import get_supabase_client
from models import BalanceRequest
from datetime import datetime
import asyncio

router = APIRouter(prefix="/balance-requests", tags=["Balance Requests"])


async def delete_request_after_delay(request_id: int, delay_seconds: int = 10):
    """Delete a balance request after specified delay"""
    await asyncio.sleep(delay_seconds)
    try:
        supabase = get_supabase_client()
        supabase.table("balance_requests").delete().eq("id", request_id).execute()
        print(f"Deleted balance request {request_id} after {delay_seconds} seconds")
    except Exception as e:
        print(f"Error deleting request {request_id}: {str(e)}")


@router.post("/create", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_balance_request(request_data: BalanceRequest):
    """Create a balance addition request from user"""
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
        
        # Check if there's already a pending request
        existing = supabase.table("balance_requests").select("*").eq(
            "merchant_id", request_data.merchant_id
        ).eq("user_id", request_data.user_id).eq("status", "pending").execute()
        
        if existing.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You already have a pending request with this merchant"
            )
        
        # Create balance request
        result = supabase.table("balance_requests").insert({
            "merchant_id": request_data.merchant_id,
            "user_id": request_data.user_id,
            "amount": request_data.amount,
            "pin": request_data.pin,
            "status": "pending"
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create balance request"
            )
        
        return {
            "message": "Balance request sent successfully",
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
async def get_merchant_requests(merchant_id: str):
    """Get all pending balance requests for a merchant"""
    try:
        supabase = get_supabase_client()
        
        result = supabase.table("balance_requests").select(
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
                "amount": req["amount"],
                "pin": req["pin"],
                "status": req["status"],
                "created_at": req["created_at"]
            })
        
        return requests
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/accept/{request_id}", response_model=dict)
async def accept_balance_request(request_id: int, background_tasks: BackgroundTasks):
    """Accept a balance request and add balance to user"""
    try:
        supabase = get_supabase_client()
        
        # Get the request
        request = supabase.table("balance_requests").select("*").eq("id", request_id).execute()
        
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
        
        # Check if link exists
        link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", req_data["merchant_id"]
        ).eq("user_id", req_data["user_id"]).execute()
        
        if link.data:
            # Update existing link balance
            link_data = link.data[0]
            new_balance = link_data["balance"] + req_data["amount"]
            
            supabase.table("merchant_user_links").update({
                "balance": new_balance
            }).eq("id", link_data["id"]).execute()
        else:
            # Create new link
            new_balance = req_data["amount"]
            supabase.table("merchant_user_links").insert({
                "merchant_id": req_data["merchant_id"],
                "user_id": req_data["user_id"],
                "pin": req_data["pin"],
                "balance": new_balance
            }).execute()
        
        # Record transaction
        supabase.table("transactions").insert({
            "merchant_id": req_data["merchant_id"],
            "user_id": req_data["user_id"],
            "amount": req_data["amount"],
            "transaction_type": "credit",
            "balance_after": new_balance
        }).execute()
        
        # Update request status
        supabase.table("balance_requests").update({
            "status": "accepted"
        }).eq("id", request_id).execute()
        
        # Schedule deletion after 10 seconds
        background_tasks.add_task(delete_request_after_delay, request_id, 10)
        
        return {
            "message": "Balance request accepted successfully",
            "amount": req_data["amount"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/reject/{request_id}", response_model=dict)
async def reject_balance_request(request_id: int, background_tasks: BackgroundTasks):
    """Reject a balance request"""
    try:
        supabase = get_supabase_client()
        
        # Get the request
        request = supabase.table("balance_requests").select("*").eq("id", request_id).execute()
        
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
        supabase.table("balance_requests").update({
            "status": "rejected"
        }).eq("id", request_id).execute()
        
        # Schedule deletion after 10 seconds
        background_tasks.add_task(delete_request_after_delay, request_id, 10)
        
        return {
            "message": "Balance request rejected",
            "user_id": request.data[0]["user_id"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
