import pytest
import os
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
import random

# Set testing environment
os.environ["TESTING"] = "True"

from main import app
from core.database import get_supabase_client
from core.utils import hash_password
from faker import Faker

fake = Faker('en_IN')


# Disable rate limiting for all tests
@pytest.fixture(scope="session", autouse=True)
def disable_rate_limiting():
    """Disable SlowAPI rate limiting during tests"""
    # Mock the limiter to do nothing
    with patch('slowapi.Limiter.limit', return_value=lambda func: func):
        yield


@pytest.fixture(scope="session")
def client():
    """Test client for making API requests"""
    return TestClient(app)


@pytest.fixture(scope="session")
def supabase():
    """Supabase client for database operations"""
    return get_supabase_client()


@pytest.fixture
def test_user(supabase):
    """Create a test user and return credentials"""
    user_id = f"UR{random.randint(100000, 999999)}"
    password = "Test@1234"
    user_name = fake.name()
    
    user_data = {
        "id": user_id,
        "user_name": user_name,
        "user_passw": hash_password(password)
    }
    
    try:
        result = supabase.table("users").insert(user_data).execute()
        
        yield {
            "user_id": user_id,
            "password": password,
            "user_name": user_name,
            "data": result.data[0] if result.data else user_data
        }
    finally:
        # Cleanup
        try:
            supabase.table("users").delete().eq("id", user_id).execute()
        except:
            pass


@pytest.fixture
def test_merchant(supabase):
    """Create a test merchant and return credentials"""
    merchant_id = f"MR{random.randint(100000, 999999)}"
    password = "Test@1234"
    phone = f"9{random.randint(100000000, 999999999)}"
    store_name = fake.company()
    
    merchant_data = {
        "id": merchant_id,
        "store_name": store_name,
        "phone": phone,
        "password": hash_password(password)
    }
    
    try:
        result = supabase.table("merchants").insert(merchant_data).execute()
        
        yield {
            "merchant_id": merchant_id,
            "password": password,
            "phone": phone,
            "store_name": store_name,
            "data": result.data[0] if result.data else merchant_data
        }
    finally:
        # Cleanup
        try:
            supabase.table("merchants").delete().eq("id", merchant_id).execute()
        except:
            pass


@pytest.fixture
def user_token(client, test_user):
    """Get JWT token for test user"""
    response = client.post("/user/login", json={
        "user_id": test_user["user_id"],
        "user_passw": test_user["password"]
    })
    
    if response.status_code != 200:
        pytest.fail(f"User login failed: {response.status_code} - {response.text}")
    
    return response.json()["access_token"]


@pytest.fixture
def merchant_token(client, test_merchant):
    """Get JWT token for test merchant"""
    response = client.post("/merchant/login", json={
        "merchant_id": test_merchant["merchant_id"],
        "merchant_passw": test_merchant["password"]
    })
    
    if response.status_code != 200:
        pytest.fail(f"Merchant login failed: {response.status_code} - {response.text}")
    
    return response.json()["access_token"]


@pytest.fixture
def test_link(supabase, test_user, test_merchant):
    """Create a link between test user and merchant"""
    pin = "1234"
    
    link_data = {
        "merchant_id": test_merchant["merchant_id"],
        "user_id": test_user["user_id"],
        "pin": hash_password(pin),
        "balance": 1000.0,
        "status": "active"
    }
    
    result = None
    try:
        result = supabase.table("merchant_user_links").insert(link_data).execute()
        
        yield {
            "link_id": result.data[0]["id"],
            "pin": pin,
            "merchant_id": test_merchant["merchant_id"],
            "user_id": test_user["user_id"],
            "balance": 1000.0,
            "data": result.data[0]
        }
    finally:
        # Cleanup
        try:
            if result and result.data:
                supabase.table("merchant_user_links").delete().eq("id", result.data[0]["id"]).execute()
        except:
            pass


@pytest.fixture
def test_pay_request(supabase, test_link):
    """Create a test pay request"""
    request_data = {
        "merchant_id": test_link["merchant_id"],
        "user_id": test_link["user_id"],
        "amount": 500.0,
        "description": "Test payment request",
        "status": "pending"
    }
    
    result = None
    try:
        result = supabase.table("pay_requests").insert(request_data).execute()
        
        yield {
            "request_id": result.data[0]["id"],
            "merchant_id": test_link["merchant_id"],
            "user_id": test_link["user_id"],
            "amount": 500.0,
            "data": result.data[0]
        }
    finally:
        # Cleanup
        try:
            if result and result.data:
                supabase.table("pay_requests").delete().eq("id", result.data[0]["id"]).execute()
        except:
            pass