from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from core.database import get_supabase_client
from middleware.auth_middleware import verify_token
from core.websocket_manager import manager
import bcrypt

router = APIRouter()

class CreatePayRequest(BaseModel):
    merchant_id: str
    user_id: str
    amount: float
    description: Optional[str] = None

class AcceptPayRequest(BaseModel):
    request_id: int
    pin: str

@router.post("/pay-requests/create")
async def create_pay_request(
    request: CreatePayRequest,
    authorization: str = Header(None)
):
    """Merchant creates a pay request to user"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    token = authorization.replace("Bearer ", "")
    user_data = verify_token(token)
    if not user_data or user_data.get("sub") != request.merchant_id:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    
    try:
        supabase = get_supabase_client()
        
        # Verify link exists and get current balance
        link_result = supabase.table("merchant_user_links")\
            .select("balance, store_name")\
            .eq("merchant_id", request.merchant_id)\
            .eq("user_id", request.user_id)\
            .eq("status", "active")\
            .execute()
        
        if not link_result.data:
            raise HTTPException(status_code=404, detail="Link not found or inactive")
        
        balance = link_result.data[0]["balance"]
        
        # Check if user has sufficient balance
        if balance < request.amount:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient balance. Available: ₹{balance:.2f}"
            )
        
        # Create pay request
        pay_req_result = supabase.table("pay_requests").insert({
            "merchant_id": request.merchant_id,
            "user_id": request.user_id,
            "amount": request.amount,
            "description": request.description,
            "status": "pending"
        }).execute()
        
        if not pay_req_result.data:
            raise HTTPException(status_code=500, detail="Failed to create pay request")
        
        # Broadcast to user via WebSocket if connected
        if manager.is_user_connected(request.user_id):
            await manager.broadcast_payment_request_to_user(
                request.user_id,
                {
                    "request_id": pay_req_result.data[0]["id"],
                    "merchant_id": request.merchant_id,
                    "amount": request.amount,
                    "description": request.description,
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
        return {
            "message": "Pay request sent successfully",
            "request_id": pay_req_result.data[0]["id"],
            "amount": request.amount,
            "status": "pending"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/pay-requests/user/{user_id}")
async def get_user_pay_requests(
    user_id: str,
    authorization: str = Header(None)
):
    """Get all pay requests for a user"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    token = authorization.replace("Bearer ", "")
    user_data = verify_token(token)
    if not user_data or user_data.get("sub") != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        supabase = get_supabase_client()
        
        result = supabase.table("pay_requests")\
            .select(
                "id, merchant_id, amount, description, status, created_at, responded_at, "
                "merchants(store_name)"
            )\
            .eq("user_id", user_id)\
            .order("created_at", desc=True)\
            .execute()
        
        requests = []
        for r in result.data:
            store_name = r.get("merchants", {}).get("store_name") if isinstance(r.get("merchants"), dict) else None
            requests.append({
                "id": r["id"],
                "merchant_id": r["merchant_id"],
                "amount": r["amount"],
                "description": r["description"],
                "status": r["status"],
                "created_at": r["created_at"],
                "responded_at": r.get("responded_at"),
                "store_name": store_name
            })
        
        return requests
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/pay-requests/merchant/{merchant_id}")
async def get_merchant_pay_requests(
    merchant_id: str,
    authorization: str = Header(None)
):
    """Get all pay requests created by a merchant"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    token = authorization.replace("Bearer ", "")
    user_data = verify_token(token)
    if not user_data or user_data.get("sub") != merchant_id:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        supabase = get_supabase_client()
        
        result = supabase.table("pay_requests")\
            .select(
                "id, user_id, amount, description, status, created_at, responded_at, "
                "merchant_user_links(user_name)"
            )\
            .eq("merchant_id", merchant_id)\
            .order("created_at", desc=True)\
            .execute()
        
        requests = []
        for r in result.data:
            user_name = r.get("merchant_user_links", {}).get("user_name") if isinstance(r.get("merchant_user_links"), dict) else None
            requests.append({
                "id": r["id"],
                "user_id": r["user_id"],
                "amount": r["amount"],
                "description": r["description"],
                "status": r["status"],
                "created_at": r["created_at"],
                "responded_at": r.get("responded_at"),
                "user_name": user_name
            })
        
        return requests
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/pay-requests/accept")
async def accept_pay_request(
    request: AcceptPayRequest,
    authorization: str = Header(None)
):
    """User accepts pay request with PIN verification"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    token = authorization.replace("Bearer ", "")
    user_data = verify_token(token)
    if not user_data:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        supabase = get_supabase_client()
        
        # Get pay request details
        pay_req_result = supabase.table("pay_requests")\
            .select("*")\
            .eq("id", request.request_id)\
            .execute()
        
        if not pay_req_result.data:
            raise HTTPException(status_code=404, detail="Pay request not found")
        
        pay_req = pay_req_result.data[0]
        
        # Verify user owns this request
        if pay_req["user_id"] != user_data.get("sub"):
            raise HTTPException(status_code=403, detail="Unauthorized")
        
        if pay_req["status"] != "pending":
            raise HTTPException(status_code=400, detail=f"Request already {pay_req['status']}")
        
        # Get link and verify PIN
        link_result = supabase.table("merchant_user_links")\
            .select("pin_hash, balance, store_name, user_name")\
            .eq("merchant_id", pay_req["merchant_id"])\
            .eq("user_id", pay_req["user_id"])\
            .execute()
        
        if not link_result.data:
            raise HTTPException(status_code=404, detail="Link not found")
        
        link = link_result.data[0]
        
        # Verify PIN
        if not bcrypt.checkpw(request.pin.encode('utf-8'), link["pin_hash"].encode('utf-8')):
            raise HTTPException(status_code=401, detail="Invalid PIN")
        
        # Check balance
        if link["balance"] < pay_req["amount"]:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient balance. Available: ₹{link['balance']:.2f}"
            )
        
        # Deduct balance
        new_balance = link["balance"] - pay_req["amount"]
        supabase.table("merchant_user_links")\
            .update({"balance": new_balance})\
            .eq("merchant_id", pay_req["merchant_id"])\
            .eq("user_id", pay_req["user_id"])\
            .execute()
        
        # Update pay request status
        supabase.table("pay_requests")\
            .update({
                "status": "accepted",
                "responded_at": datetime.utcnow().isoformat()
            })\
            .eq("id", request.request_id)\
            .execute()
        
        # Create transaction record
        supabase.table("transactions").insert({
            "merchant_id": pay_req["merchant_id"],
            "user_id": pay_req["user_id"],
            "amount": pay_req["amount"],
            "transaction_type": "purchase",
            "store_name": link["store_name"]
        }).execute()
        
        # Broadcast to merchant via WebSocket if connected
        if manager.is_merchant_connected(pay_req["merchant_id"]):
            await manager.broadcast_payment_to_merchant(
                pay_req["merchant_id"],
                {
                    "user_id": pay_req["user_id"],
                    "amount": pay_req["amount"],
                    "remaining_balance": new_balance,
                    "timestamp": datetime.utcnow().isoformat()
                }
            )
        
        return {
            "message": "Payment successful",
            "amount": pay_req["amount"],
            "new_balance": new_balance,
            "store_name": link["store_name"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/pay-requests/reject/{request_id}")
async def reject_pay_request(
    request_id: int,
    authorization: str = Header(None)
):
    """User rejects pay request"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    token = authorization.replace("Bearer ", "")
    user_data = verify_token(token)
    if not user_data:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        supabase = get_supabase_client()
        
        # Get pay request
        pay_req_result = supabase.table("pay_requests")\
            .select("user_id, status")\
            .eq("id", request_id)\
            .execute()
        
        if not pay_req_result.data:
            raise HTTPException(status_code=404, detail="Pay request not found")
        
        pay_req = pay_req_result.data[0]
        
        if pay_req["user_id"] != user_data.get("sub"):
            raise HTTPException(status_code=403, detail="Unauthorized")
        
        if pay_req["status"] != "pending":
            raise HTTPException(status_code=400, detail=f"Request already {pay_req['status']}")
        
        # Update status
        supabase.table("pay_requests")\
            .update({
                "status": "rejected",
                "responded_at": datetime.utcnow().isoformat()
            })\
            .eq("id", request_id)\
            .execute()
        
        return {"message": "Pay request rejected"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
