"""
Tests for OAuth Routes
Note: These tests require mocking Google OAuth verification
"""
import pytest
from unittest.mock import patch, MagicMock
from faker import Faker

fake = Faker()


class TestGoogleOAuth:
    """Test Google OAuth login/registration endpoint"""
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_oauth_register_user_success(self, mock_verify, client):
        """Test successful user registration via OAuth"""
        # Mock Google token verification
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_data = {
            "id_token": "mock_google_token",
            "user_type": "user"
        }
        
        response = client.post("/oauth/google", json=oauth_data)
        
        assert response.status_code == 200
        data = response.json()
        assert "user_id" in data
        assert "access_token" in data
        assert data["profile_completed"] == False
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_oauth_register_merchant_success(self, mock_verify, client):
        """Test successful merchant registration via OAuth"""
        # Mock Google token verification
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_data = {
            "id_token": "mock_google_token",
            "user_type": "merchant"
        }
        
        response = client.post("/oauth/google", json=oauth_data)
        
        assert response.status_code == 200
        data = response.json()
        assert "merchant_id" in data
        assert "access_token" in data
        assert data["profile_completed"] == False
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_oauth_login_existing_user(self, mock_verify, client, test_user, supabase):
        """Test OAuth login for existing user"""
        google_id = fake.uuid4()
        google_email = fake.email()
        
        # Update test user with Google credentials
        supabase.table("users").update({
            "google_id": google_id,
            "google_email": google_email
        }).eq("id", test_user["user_id"]).execute()
        
        # Mock Google token verification
        mock_verify.return_value = {
            'email': google_email,
            'name': test_user["user_name"],
            'sub': google_id
        }
        
        oauth_data = {
            "id_token": "mock_google_token",
            "user_type": "user"
        }
        
        response = client.post("/oauth/google", json=oauth_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == test_user["user_id"]
        assert "access_token" in data
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_oauth_invalid_token(self, mock_verify, client):
        """Test OAuth with invalid token"""
        # Mock token verification failure
        mock_verify.side_effect = ValueError("Invalid token")
        
        oauth_data = {
            "id_token": "invalid_token",
            "user_type": "user"
        }
        
        response = client.post("/oauth/google", json=oauth_data)
        
        assert response.status_code == 401
        assert "Invalid Google token" in response.json()["detail"]
    
    def test_oauth_invalid_user_type(self, client):
        """Test OAuth with invalid user type"""
        oauth_data = {
            "id_token": "mock_token",
            "user_type": "invalid_type"
        }
        
        response = client.post("/oauth/google", json=oauth_data)
        
        # Should fail validation or return error
        assert response.status_code in [400, 401, 422]


class TestCompleteMerchantProfile:
    """Test complete merchant OAuth profile endpoint"""
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_complete_merchant_profile_success(self, mock_verify, client):
        """Test successful merchant profile completion"""
        # Create OAuth merchant first
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_data = {
            "id_token": "mock_token",
            "user_type": "merchant"
        }
        
        oauth_response = client.post("/oauth/google", json=oauth_data)
        merchant_id = oauth_response.json()["merchant_id"]
        token = oauth_response.json()["access_token"]
        
        # Complete profile
        headers = {"Authorization": f"Bearer {token}"}
        profile_data = {
            "merchant_id": merchant_id,
            "store_name": fake.company(),
            "owner_name": fake.name(),
            "phone": fake.phone_number()[:15],
            "store_address": fake.address()[:100]
        }
        
        response = client.post("/oauth/merchant/complete-profile", json=profile_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["profile_completed"] == True
        assert data["store_name"] == profile_data["store_name"]
    
    def test_complete_merchant_profile_unauthorized(self, client):
        """Test completing profile without token"""
        profile_data = {
            "merchant_id": "MER123456789",
            "store_name": fake.company(),
            "owner_name": fake.name()
        }
        
        response = client.post("/oauth/merchant/complete-profile", json=profile_data)
        
        assert response.status_code == 401
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_complete_merchant_profile_wrong_merchant(self, mock_verify, client):
        """Test completing another merchant's profile"""
        # Create OAuth merchant
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_response = client.post("/oauth/google", json={
            "id_token": "mock_token",
            "user_type": "merchant"
        })
        token = oauth_response.json()["access_token"]
        
        # Try to complete different merchant's profile
        headers = {"Authorization": f"Bearer {token}"}
        profile_data = {
            "merchant_id": "MER999999999",
            "store_name": fake.company(),
            "owner_name": fake.name()
        }
        
        response = client.post("/oauth/merchant/complete-profile", json=profile_data, headers=headers)
        
        assert response.status_code in [403, 404]


class TestCompleteUserProfile:
    """Test complete user OAuth profile endpoint"""
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_complete_user_profile_success(self, mock_verify, client):
        """Test successful user profile completion"""
        # Create OAuth user first
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_data = {
            "id_token": "mock_token",
            "user_type": "user"
        }
        
        oauth_response = client.post("/oauth/google", json=oauth_data)
        user_id = oauth_response.json()["user_id"]
        token = oauth_response.json()["access_token"]
        
        # Complete profile
        headers = {"Authorization": f"Bearer {token}"}
        profile_data = {
            "user_id": user_id,
            "user_name": fake.user_name(),
            "phone": fake.phone_number()[:15]
        }
        
        response = client.post("/oauth/user/complete-profile", json=profile_data, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["profile_completed"] == True
        assert data["user_name"] == profile_data["user_name"]
    
    def test_complete_user_profile_unauthorized(self, client):
        """Test completing profile without token"""
        profile_data = {
            "user_id": "USR123456789",
            "user_name": fake.user_name()
        }
        
        response = client.post("/oauth/user/complete-profile", json=profile_data)
        
        assert response.status_code == 401
    
    @patch('oauth_routes.id_token.verify_oauth2_token')
    def test_complete_user_profile_missing_fields(self, mock_verify, client):
        """Test completing profile with missing fields"""
        # Create OAuth user
        mock_verify.return_value = {
            'email': fake.email(),
            'name': fake.name(),
            'sub': fake.uuid4()
        }
        
        oauth_response = client.post("/oauth/google", json={
            "id_token": "mock_token",
            "user_type": "user"
        })
        token = oauth_response.json()["access_token"]
        
        # Try to complete with missing fields
        headers = {"Authorization": f"Bearer {token}"}
        profile_data = {
            "user_id": oauth_response.json()["user_id"]
            # Missing user_name
        }
        
        response = client.post("/oauth/user/complete-profile", json=profile_data, headers=headers)
        
        assert response.status_code == 422  # Validation error
