from fastapi import APIRouter, HTTPException, status
from database import get_supabase_client
from models import MerchantUserLink, AddBalance, ProcessTransaction, TransactionResponse
from utils import hash_password, verify_password

router = APIRouter(prefix="/link", tags=["Merchant-User Link"])


@router.post("/create", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_link(link_data: MerchantUserLink):
    """Create a link between merchant and user with PIN"""
    try:
        supabase = get_supabase_client()
        
        # Verify merchant exists
        merchant = supabase.table("merchants").select("*").eq("id", link_data.merchant_id).execute()
        if not merchant.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Merchant not found"
            )
        
        # Verify user exists
        user = supabase.table("users").select("*").eq("id", link_data.user_id).execute()
        if not user.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Check if link already exists
        existing_link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", link_data.merchant_id
        ).eq("user_id", link_data.user_id).execute()
        
        if existing_link.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Link already exists between this merchant and user"
            )
        
        # Hash PIN
        hashed_pin = hash_password(link_data.pin)
        
        # Create link
        result = supabase.table("merchant_user_links").insert({
            "merchant_id": link_data.merchant_id,
            "user_id": link_data.user_id,
            "pin": hashed_pin,
            "balance": 0.0
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create link"
            )
        
        return {
            "message": "Link created successfully",
            "link_id": result.data[0]["id"],
            "merchant_id": link_data.merchant_id,
            "user_id": link_data.user_id,
            "balance": 0.0
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/delink", response_model=dict)
async def delink_merchant(link_data: ProcessTransaction):
    """Delink merchant and user with PIN verification"""
    try:
        supabase = get_supabase_client()
        
        # Get the link
        link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", link_data.merchant_id
        ).eq("user_id", link_data.user_id).execute()
        
        if not link.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No link found between this merchant and user"
            )
        
        link_record = link.data[0]
        
        # Verify PIN
        if not verify_password(link_data.pin, link_record["pin"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid PIN"
            )
        
        # Delete the link
        delete_result = supabase.table("merchant_user_links").delete().eq(
            "id", link_record["id"]
        ).execute()
        
        if not delete_result:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delink"
            )
        
        return {
            "message": "Successfully delinked",
            "merchant_id": link_data.merchant_id,
            "user_id": link_data.user_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/add-balance", response_model=dict)
async def add_balance(balance_data: AddBalance):
    """Add balance to user account for a specific merchant"""
    try:
        supabase = get_supabase_client()
        
        # Get the link
        link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", balance_data.merchant_id
        ).eq("user_id", balance_data.user_id).execute()
        
        if not link.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No link found between this merchant and user"
            )
        
        link_data = link.data[0]
        
        # Verify PIN
        if not verify_password(balance_data.pin, link_data["pin"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid PIN"
            )
        
        current_balance = link_data["balance"]
        new_balance = current_balance + balance_data.amount
        
        # Update balance
        update_result = supabase.table("merchant_user_links").update({
            "balance": new_balance
        }).eq("id", link_data["id"]).execute()
        
        if not update_result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update balance"
            )
        
        # Record transaction
        transaction = supabase.table("transactions").insert({
            "merchant_id": balance_data.merchant_id,
            "user_id": balance_data.user_id,
            "amount": balance_data.amount,
            "transaction_type": "credit",
            "balance_after": new_balance
        }).execute()
        
        return {
            "message": "Balance added successfully",
            "merchant_id": balance_data.merchant_id,
            "user_id": balance_data.user_id,
            "amount_added": balance_data.amount,
            "new_balance": new_balance,
            "transaction_id": transaction.data[0]["id"] if transaction.data else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.post("/purchase", response_model=dict)
async def process_purchase(transaction_data: ProcessTransaction):
    """Process a purchase transaction with PIN validation"""
    try:
        supabase = get_supabase_client()
        
        # Get the link
        link = supabase.table("merchant_user_links").select("*").eq(
            "merchant_id", transaction_data.merchant_id
        ).eq("user_id", transaction_data.user_id).execute()
        
        if not link.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No link found between this merchant and user"
            )
        
        link_data = link.data[0]
        
        # Verify PIN
        if not verify_password(transaction_data.pin, link_data["pin"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid PIN"
            )
        
        # Check sufficient balance
        current_balance = link_data["balance"]
        if current_balance < transaction_data.amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient balance. Current balance: {current_balance}"
            )
        
        # Calculate new balance
        new_balance = current_balance - transaction_data.amount
        
        # Update balance
        update_result = supabase.table("merchant_user_links").update({
            "balance": new_balance
        }).eq("id", link_data["id"]).execute()
        
        if not update_result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to process transaction"
            )
        
        # Record transaction
        transaction = supabase.table("transactions").insert({
            "merchant_id": transaction_data.merchant_id,
            "user_id": transaction_data.user_id,
            "amount": transaction_data.amount,
            "transaction_type": "debit",
            "balance_after": new_balance
        }).execute()
        
        return {
            "message": "Purchase successful",
            "merchant_id": transaction_data.merchant_id,
            "user_id": transaction_data.user_id,
            "amount_paid": transaction_data.amount,
            "remaining_balance": new_balance,
            "transaction_id": transaction.data[0]["id"] if transaction.data else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/balance/{merchant_id}/{user_id}", response_model=dict)
async def get_balance(merchant_id: str, user_id: str):
    """Get balance for a specific merchant-user link"""
    try:
        supabase = get_supabase_client()
        
        link = supabase.table("merchant_user_links").select("balance").eq(
            "merchant_id", merchant_id
        ).eq("user_id", user_id).execute()
        
        if not link.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No link found between this merchant and user"
            )
        
        return {
            "merchant_id": merchant_id,
            "user_id": user_id,
            "balance": link.data[0]["balance"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/transactions/{merchant_id}/{user_id}", response_model=list)
async def get_transactions(merchant_id: str, user_id: str, limit: int = 50):
    """Get transaction history for a specific merchant-user link"""
    try:
        supabase = get_supabase_client()
        
        transactions = supabase.table("transactions").select("*").eq(
            "merchant_id", merchant_id
        ).eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
        
        return transactions.data if transactions.data else []
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )


@router.get("/user-transactions/{user_id}", response_model=list)
async def get_user_transactions(user_id: str, limit: int = 100):
    """Get all transaction history for a user across all merchants"""
    try:
        supabase = get_supabase_client()
        
        # Get all transactions for this user
        transactions_response = supabase.table("transactions").select("*").eq(
            "user_id", user_id
        ).order("created_at", desc=True).limit(limit).execute()
        
        transactions = transactions_response.data if transactions_response.data else []
        
        # Enrich transactions with merchant store names
        for txn in transactions:
            merchant = supabase.table("merchants").select("store_name").eq(
                "id", txn["merchant_id"]
            ).execute()
            if merchant.data:
                txn["store_name"] = merchant.data[0]["store_name"]
            else:
                txn["store_name"] = "Unknown Merchant"
        
        return transactions
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
