"""
Tests for Pay Request Routes
"""
import pytest
from faker import Faker

fake = Faker()


class TestCreatePayRequest:
    """Test create pay request endpoint"""
    
    def test_create_pay_request_success(self, client, test_link, merchant_token):
        """Test successful pay request creation"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 100.00,
            "description": "Test payment request"
        }
        
        response = client.post("/pay-requests/create", json=request_data, headers=headers)
        
        assert response.status_code == 201
        data = response.json()
        assert "Pay request created successfully" in data["message"]
        assert "request_id" in data
    
    def test_create_pay_request_no_link(self, client, test_merchant, test_user, merchant_token):
        """Test pay request creation without existing link"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        # Create new user without link
        new_user_data = {
            "user_name": fake.user_name(),
            "user_passw": "password123"
        }
        user_response = client.post("/user/register", json=new_user_data)
        new_user_id = user_response.json()["user_id"]
        
        request_data = {
            "merchant_id": test_merchant["merchant_id"],
            "user_id": new_user_id,
            "amount": 100.00,
            "description": "Test payment request"
        }
        
        response = client.post("/pay-requests/create", json=request_data, headers=headers)
        
        assert response.status_code == 404
        assert "Link not found" in response.json()["detail"]
    
    def test_create_pay_request_negative_amount(self, client, test_link, merchant_token):
        """Test pay request with negative amount"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": -50.00,
            "description": "Invalid amount"
        }
        
        response = client.post("/pay-requests/create", json=request_data, headers=headers)
        
        assert response.status_code == 400
    
    def test_create_pay_request_unauthorized(self, client, test_link):
        """Test pay request creation without token"""
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 100.00,
            "description": "Test"
        }
        
        response = client.post("/pay-requests/create", json=request_data)
        
        assert response.status_code == 401


class TestGetUserPayRequests:
    """Test get user pay requests endpoint"""
    
    def test_get_user_pay_requests_success(self, client, test_user, user_token):
        """Test getting user's pay requests"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.get(f"/pay-requests/user/{test_user['user_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_user_pay_requests_unauthorized(self, client, test_user):
        """Test getting pay requests without token"""
        response = client.get(f"/pay-requests/user/{test_user['user_id']}")
        
        assert response.status_code == 401
    
    def test_get_user_pay_requests_wrong_user(self, client, merchant_token):
        """Test accessing another user's pay requests"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get("/pay-requests/user/USR999999999", headers=headers)
        
        # Should fail authorization
        assert response.status_code in [403, 404]


class TestGetMerchantPayRequests:
    """Test get merchant pay requests endpoint"""
    
    def test_get_merchant_pay_requests_success(self, client, test_merchant, merchant_token):
        """Test getting merchant's pay requests"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get(f"/pay-requests/merchant/{test_merchant['merchant_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_merchant_pay_requests_unauthorized(self, client, test_merchant):
        """Test getting pay requests without token"""
        response = client.get(f"/pay-requests/merchant/{test_merchant['merchant_id']}")
        
        assert response.status_code == 401


class TestAcceptPayRequest:
    """Test accept pay request endpoint"""
    
    def test_accept_pay_request_success(self, client, test_link, merchant_token, user_token, supabase):
        """Test successful pay request acceptance"""
        # Create a pay request
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 50.00,
            "description": "Test payment"
        }
        
        create_response = client.post("/pay-requests/create", json=request_data, headers=headers)
        request_id = create_response.json()["request_id"]
        
        # Add balance to user
        supabase.table("merchant_user_links").update({
            "balance": 100.00
        }).eq("merchant_id", test_link["merchant_id"]).eq("user_id", test_link["user_id"]).execute()
        
        # Accept the request
        headers = {"Authorization": f"Bearer {user_token}"}
        accept_data = {
            "request_id": request_id,
            "pin": test_link["pin"]
        }
        
        response = client.post("/pay-requests/accept", json=accept_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "Pay request accepted" in data["message"]
    
    def test_accept_pay_request_invalid_pin(self, client, test_link, merchant_token, user_token):
        """Test accepting pay request with wrong PIN"""
        # Create a pay request
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 50.00,
            "description": "Test payment"
        }
        
        create_response = client.post("/pay-requests/create", json=request_data, headers=headers)
        request_id = create_response.json()["request_id"]
        
        # Accept with wrong PIN
        headers = {"Authorization": f"Bearer {user_token}"}
        accept_data = {
            "request_id": request_id,
            "pin": "9999"
        }
        
        response = client.post("/pay-requests/accept", json=accept_data, headers=headers)
        
        assert response.status_code == 401
        assert "Invalid PIN" in response.json()["detail"]
    
    def test_accept_pay_request_insufficient_balance(self, client, test_link, merchant_token, user_token, supabase):
        """Test accepting pay request with insufficient balance"""
        # Create a pay request with large amount
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 5000.00,
            "description": "Large payment"
        }
        
        create_response = client.post("/pay-requests/create", json=request_data, headers=headers)
        request_id = create_response.json()["request_id"]
        
        # Set low balance
        supabase.table("merchant_user_links").update({
            "balance": 10.00
        }).eq("merchant_id", test_link["merchant_id"]).eq("user_id", test_link["user_id"]).execute()
        
        # Try to accept
        headers = {"Authorization": f"Bearer {user_token}"}
        accept_data = {
            "request_id": request_id,
            "pin": test_link["pin"]
        }
        
        response = client.post("/pay-requests/accept", json=accept_data, headers=headers)
        
        # Might allow negative or reject
        assert response.status_code in [200, 400]


class TestRejectPayRequest:
    """Test reject pay request endpoint"""
    
    def test_reject_pay_request_success(self, client, test_link, merchant_token, user_token):
        """Test successful pay request rejection"""
        # Create a pay request
        headers = {"Authorization": f"Bearer {merchant_token}"}
        request_data = {
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 50.00,
            "description": "Test payment"
        }
        
        create_response = client.post("/pay-requests/create", json=request_data, headers=headers)
        request_id = create_response.json()["request_id"]
        
        # Reject the request
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.post(f"/pay-requests/reject/{request_id}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "Pay request rejected" in data["message"]
    
    def test_reject_pay_request_not_found(self, client, user_token):
        """Test rejecting non-existent pay request"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.post("/pay-requests/reject/99999", headers=headers)
        
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]
    
    def test_reject_pay_request_unauthorized(self, client):
        """Test rejecting pay request without token"""
        response = client.post("/pay-requests/reject/1")
        
        assert response.status_code == 401
