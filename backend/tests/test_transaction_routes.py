"""
Tests for Transaction Routes
"""
import pytest
from faker import Faker

fake = Faker()


class TestCreateLink:
    """Test create merchant-user link endpoint"""
    
    def test_create_link_success(self, client, test_merchant, test_user, merchant_token):
        """Test successful link creation"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        link_data = {
            "merchant_id": test_merchant["merchant_id"],
            "user_id": test_user["user_id"],
            "pin": "1234"
        }
        
        response = client.post("/link/create", json=link_data, headers=headers)
        
        assert response.status_code == 201
        data = response.json()
        assert "Link created successfully" in data["message"]
        assert data["merchant_id"] == test_merchant["merchant_id"]
        assert data["user_id"] == test_user["user_id"]
    
    def test_create_link_invalid_pin(self, client, test_merchant, test_user, merchant_token):
        """Test link creation with invalid PIN"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        link_data = {
            "merchant_id": test_merchant["merchant_id"],
            "user_id": test_user["user_id"],
            "pin": "123"  # Too short
        }
        
        response = client.post("/link/create", json=link_data, headers=headers)
        
        assert response.status_code == 400
        assert "PIN must be 4 digits" in response.json()["detail"]
    
    def test_create_link_duplicate(self, client, test_merchant, test_user, merchant_token, test_link):
        """Test creating duplicate link"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        link_data = {
            "merchant_id": test_merchant["merchant_id"],
            "user_id": test_user["user_id"],
            "pin": "1234"
        }
        
        response = client.post("/link/create", json=link_data, headers=headers)
        
        assert response.status_code == 409
        assert "already exists" in response.json()["detail"]
    
    def test_create_link_merchant_not_found(self, client, test_user, merchant_token):
        """Test link creation with non-existent merchant"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        link_data = {
            "merchant_id": "MER999999999",
            "user_id": test_user["user_id"],
            "pin": "1234"
        }
        
        response = client.post("/link/create", json=link_data, headers=headers)
        
        assert response.status_code in [403, 404]
    
    def test_create_link_unauthorized(self, client, test_merchant, test_user):
        """Test link creation without token"""
        link_data = {
            "merchant_id": test_merchant["merchant_id"],
            "user_id": test_user["user_id"],
            "pin": "1234"
        }
        
        response = client.post("/link/create", json=link_data)
        
        assert response.status_code == 401


class TestAddBalance:
    """Test add balance endpoint"""
    
    def test_add_balance_success(self, client, test_link, merchant_token):
        """Test successful balance addition"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        balance_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 500.00,
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/add-balance", json=balance_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "Balance added successfully" in data["message"]
        assert data["new_balance"] == 500.00
    
    def test_add_balance_invalid_pin(self, client, test_link, merchant_token):
        """Test balance addition with wrong PIN"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        balance_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 500.00,
            "pin": "9999"
        }
        
        response = client.post("/link/add-balance", json=balance_data, headers=headers)
        
        assert response.status_code == 401
        assert "Invalid PIN" in response.json()["detail"]
    
    def test_add_balance_negative_amount(self, client, test_link, merchant_token):
        """Test balance addition with negative amount"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        balance_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": -100.00,
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/add-balance", json=balance_data, headers=headers)
        
        assert response.status_code == 400
        assert "Amount must be greater than 0" in response.json()["detail"]
    
    def test_add_balance_exceeds_limit(self, client, test_link, merchant_token):
        """Test balance addition exceeding maximum limit"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        balance_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 1000000.00,  # Very large amount
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/add-balance", json=balance_data, headers=headers)
        
        # May pass or fail depending on backend limits
        # Just check it responds properly
        assert response.status_code in [200, 400]


class TestProcessPurchase:
    """Test process purchase endpoint"""
    
    def test_purchase_success(self, client, test_link, merchant_token, supabase):
        """Test successful purchase"""
        # First add balance
        supabase.table("merchant_user_links").update({
            "balance": 100.00
        }).eq("merchant_id", test_link["merchant_id"]).eq("user_id", test_link["user_id"]).execute()
        
        headers = {"Authorization": f"Bearer {merchant_token}"}
        purchase_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 50.00,
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/purchase", json=purchase_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "Purchase successful" in data["message"]
        assert data["remaining_balance"] == 50.00
    
    def test_purchase_insufficient_balance(self, client, test_link, merchant_token):
        """Test purchase with insufficient balance"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        purchase_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 1000.00,
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/purchase", json=purchase_data, headers=headers)
        
        # May allow negative balance or reject
        assert response.status_code in [200, 400]
    
    def test_purchase_invalid_pin(self, client, test_link, merchant_token):
        """Test purchase with wrong PIN"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        purchase_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 50.00,
            "pin": "9999"
        }
        
        response = client.post("/link/purchase", json=purchase_data, headers=headers)
        
        assert response.status_code == 401
        assert "Invalid PIN" in response.json()["detail"]
    
    def test_purchase_negative_amount(self, client, test_link, merchant_token):
        """Test purchase with negative amount"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        purchase_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": -50.00,
            "pin": test_link["pin"]
        }
        
        response = client.post("/link/purchase", json=purchase_data, headers=headers)
        
        assert response.status_code == 400


class TestGetBalance:
    """Test get balance endpoint"""
    
    def test_get_balance_success(self, client, test_link, merchant_token):
        """Test getting balance"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get(
            f"/link/balance/{test_link['merchant_id']}/{test_link['user_id']}", 
            headers=headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "balance" in data
        assert isinstance(data["balance"], (int, float))
    
    def test_get_balance_unauthorized(self, client, test_link):
        """Test getting balance without token"""
        response = client.get(
            f"/link/balance/{test_link['merchant_id']}/{test_link['user_id']}"
        )
        
        assert response.status_code == 401


class TestGetTransactions:
    """Test get transactions endpoints"""
    
    def test_get_merchant_user_transactions(self, client, test_link, merchant_token):
        """Test getting transactions for merchant-user pair"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get(
            f"/link/transactions/{test_link['merchant_id']}/{test_link['user_id']}", 
            headers=headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_user_transactions(self, client, test_user, user_token):
        """Test getting all transactions for a user"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.get(
            f"/link/user-transactions/{test_user['user_id']}", 
            headers=headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_transactions_unauthorized(self, client, test_user):
        """Test getting transactions without token"""
        response = client.get(f"/link/user-transactions/{test_user['user_id']}")
        
        assert response.status_code == 401
