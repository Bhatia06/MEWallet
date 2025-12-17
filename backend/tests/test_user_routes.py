"""
Tests for User Routes
"""
import pytest
from faker import Faker

fake = Faker()


class TestUserRegistration:
    """Test user registration endpoint"""
    
    def test_register_user_success(self, client):
        """Test successful user registration"""
        user_data = {
            "user_name": fake.user_name(),
            "user_passw": fake.password()
        }
        
        response = client.post("/user/register", json=user_data)
        
        assert response.status_code == 201
        data = response.json()
        assert "user_id" in data
        assert data["user_name"] == user_data["user_name"]
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_register_user_missing_name(self, client):
        """Test registration with missing user_name"""
        user_data = {
            "user_passw": fake.password()
        }
        
        response = client.post("/user/register", json=user_data)
        
        assert response.status_code == 422  # Validation error
    
    def test_register_user_missing_password(self, client):
        """Test registration with missing password"""
        user_data = {
            "user_name": fake.user_name()
        }
        
        response = client.post("/user/register", json=user_data)
        
        assert response.status_code == 422  # Validation error


class TestUserLogin:
    """Test user login endpoint"""
    
    def test_login_user_success(self, client, test_user):
        """Test successful user login"""
        login_data = {
            "user_id": test_user["user_id"],
            "user_passw": test_user["password"]
        }
        
        response = client.post("/user/login", json=login_data)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user_id"] == test_user["user_id"]
        assert data["token_type"] == "bearer"
    
    def test_login_user_invalid_password(self, client, test_user):
        """Test login with invalid password"""
        login_data = {
            "user_id": test_user["user_id"],
            "user_passw": "wrongpassword123"
        }
        
        response = client.post("/user/login", json=login_data)
        
        assert response.status_code == 401
        assert "Invalid credentials" in response.json()["detail"]
    
    def test_login_user_nonexistent(self, client):
        """Test login with non-existent user"""
        login_data = {
            "user_id": "USR999999999",
            "user_passw": "password123"
        }
        
        response = client.post("/user/login", json=login_data)
        
        assert response.status_code == 401
        assert "User not found" in response.json()["detail"]
    
    def test_login_user_missing_credentials(self, client):
        """Test login with missing credentials"""
        response = client.post("/user/login", json={})
        
        assert response.status_code == 422  # Validation error


class TestUserProfile:
    """Test user profile endpoint"""
    
    def test_get_user_profile_success(self, client, test_user, user_token):
        """Test getting user profile"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.get(f"/user/profile/{test_user['user_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == test_user["user_id"]
        assert data["user_name"] == test_user["user_name"]
    
    def test_get_user_profile_unauthorized(self, client, test_user):
        """Test getting profile without token"""
        response = client.get(f"/user/profile/{test_user['user_id']}")
        
        assert response.status_code == 401
    
    def test_get_user_profile_wrong_user(self, client, test_user, user_token):
        """Test accessing another user's profile"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.get("/user/profile/USR999999999", headers=headers)
        
        assert response.status_code in [403, 404]  # Forbidden or Not Found


class TestLinkedMerchants:
    """Test linked merchants endpoint"""
    
    def test_get_linked_merchants_success(self, client, test_user, user_token, test_link):
        """Test getting linked merchants"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        response = client.get(f"/user/linked-merchants/{test_user['user_id']}", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_get_linked_merchants_unauthorized(self, client, test_user):
        """Test getting linked merchants without token"""
        response = client.get(f"/user/linked-merchants/{test_user['user_id']}")
        
        assert response.status_code == 401
    
    def test_get_linked_merchants_empty(self, client, test_user, user_token):
        """Test getting linked merchants when none exist"""
        headers = {"Authorization": f"Bearer {user_token}"}
        
        # Create a new user without links
        new_user_data = {
            "user_name": fake.user_name(),
            "user_passw": "password123"
        }
        reg_response = client.post("/user/register", json=new_user_data)
        new_user_id = reg_response.json()["user_id"]
        new_token = reg_response.json()["access_token"]
        
        headers = {"Authorization": f"Bearer {new_token}"}
        response = client.get(f"/user/linked-merchants/{new_user_id}", headers=headers)
        
        assert response.status_code == 200
        assert response.json() == []
