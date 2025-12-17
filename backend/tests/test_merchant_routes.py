"""
Tests for Merchant Routes
"""
import pytest
from faker import Faker

fake = Faker()


class TestMerchantRegistration:
    """Test merchant registration endpoint"""
    
    def test_register_merchant_success(self, client):
        """Test successful merchant registration"""
        merchant_data = {
            "store_name": fake.company(),
            "phone": fake.phone_number()[:15],
            "password": fake.password()
        }
        
        response = client.post("/merchant/register", json=merchant_data)
        
        assert response.status_code == 201
        data = response.json()
        assert "merchant_id" in data
        assert data["store_name"] == merchant_data["store_name"]
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_register_merchant_duplicate_phone(self, client, test_merchant):
        """Test registration with duplicate phone number"""
        merchant_data = {
            "store_name": fake.company(),
            "phone": test_merchant["phone"],
            "password": fake.password()
        }
        
        response = client.post("/merchant/register", json=merchant_data)
        
        assert response.status_code == 400
        assert "already registered" in response.json()["detail"]
    
    def test_register_merchant_missing_fields(self, client):
        """Test registration with missing fields"""
        merchant_data = {
            "store_name": fake.company()
            # Missing phone and password
        }
        
        response = client.post("/merchant/register", json=merchant_data)
        
        assert response.status_code == 422  # Validation error
    
    def test_register_merchant_invalid_phone(self, client):
        """Test registration with empty phone"""
        merchant_data = {
            "store_name": fake.company(),
            "phone": "",
            "password": fake.password()
        }
        
        response = client.post("/merchant/register", json=merchant_data)
        
        assert response.status_code in [400, 422]


class TestMerchantLogin:
    """Test merchant login endpoint"""
    
    def test_login_merchant_success(self, client, test_merchant):
        """Test successful merchant login"""
        login_data = {
            "phone": test_merchant["phone"],
            "password": test_merchant["password"]
        }
        
        response = client.post("/merchant/login", json=login_data)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["merchant_id"] == test_merchant["merchant_id"]
        assert data["token_type"] == "bearer"
    
    def test_login_merchant_invalid_password(self, client, test_merchant):
        """Test login with invalid password"""
        login_data = {
            "phone": test_merchant["phone"],
            "password": "wrongpassword123"
        }
        
        response = client.post("/merchant/login", json=login_data)
        
        assert response.status_code == 401
        assert "Invalid credentials" in response.json()["detail"]
    
    def test_login_merchant_nonexistent(self, client):
        """Test login with non-existent merchant"""
        login_data = {
            "phone": "9999999999",
            "password": "password123"
        }
        
        response = client.post("/merchant/login", json=login_data)
        
        assert response.status_code == 401
        assert "Merchant not found" in response.json()["detail"]
    
    def test_login_merchant_missing_credentials(self, client):
        """Test login with missing credentials"""
        response = client.post("/merchant/login", json={})
        
        assert response.status_code == 422  # Validation error


class TestMerchantProfile:
    """Test merchant profile endpoint"""
    
    def test_get_merchant_profile_success(self, client, test_merchant, merchant_token):
        """Test getting merchant profile"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get(f"/merchant/profile/{test_merchant['merchant_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["merchant_id"] == test_merchant["merchant_id"]
        assert data["store_name"] == test_merchant["store_name"]
    
    def test_get_merchant_profile_unauthorized(self, client, test_merchant):
        """Test getting profile without token"""
        response = client.get(f"/merchant/profile/{test_merchant['merchant_id']}")
        
        assert response.status_code == 401
    
    def test_get_merchant_profile_wrong_merchant(self, client, test_merchant, merchant_token):
        """Test accessing another merchant's profile"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get("/merchant/profile/MER999999999", headers=headers)
        
        assert response.status_code in [403, 404]  # Forbidden or Not Found


class TestLinkedUsers:
    """Test linked users endpoint"""
    
    def test_get_linked_users_success(self, client, test_merchant, merchant_token, test_link):
        """Test getting linked users"""
        headers = {"Authorization": f"Bearer {merchant_token}"}
        
        response = client.get(f"/merchant/linked-users/{test_merchant['merchant_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_linked_users_unauthorized(self, client, test_merchant):
        """Test getting linked users without token"""
        response = client.get(f"/merchant/linked-users/{test_merchant['merchant_id']}")
        
        assert response.status_code == 401
    
    def test_get_linked_users_empty(self, client, merchant_token):
        """Test getting linked users when none exist"""
        # Create a new merchant without links
        merchant_data = {
            "store_name": fake.company(),
            "phone": fake.phone_number()[:15],
            "password": "password123"
        }
        reg_response = client.post("/merchant/register", json=merchant_data)
        new_merchant_id = reg_response.json()["merchant_id"]
        new_token = reg_response.json()["access_token"]
        
        headers = {"Authorization": f"Bearer {new_token}"}
        response = client.get(f"/merchant/linked-users/{new_merchant_id}", headers=headers)
        
        assert response.status_code == 200
        assert response.json() == []
