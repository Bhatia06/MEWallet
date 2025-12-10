import requests
import json

BASE_URL = "http://localhost:8000"

def print_section(title):
    print("\n" + "="*50)
    print(f"  {title}")
    print("="*50)

def test_health():
    print_section("Testing Health Check")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_merchant_registration():
    print_section("Testing Merchant Registration")
    data = {
        "store_name": "Test Store",
        "phone": "9876543210",
        "password": "password123"
    }
    response = requests.post(f"{BASE_URL}/merchant/register", json=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    if response.status_code == 201:
        return response.json()
    return None

def test_merchant_login(phone, password):
    print_section("Testing Merchant Login")
    data = {
        "phone": phone,
        "password": password
    }
    response = requests.post(f"{BASE_URL}/merchant/login", json=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    if response.status_code == 200:
        return response.json()
    return None

def test_user_registration():
    print_section("Testing User Registration")
    data = {
        "user_name": "Test User",
        "user_passw": "password123"
    }
    response = requests.post(f"{BASE_URL}/user/register", json=data)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    if response.status_code == 201:
        return response.json()
    return None

def test_create_link(merchant_id, user_id, token):
    print_section("Testing Link Creation")
    data = {
        "merchant_id": merchant_id,
        "user_id": user_id,
        "pin": "1234"
    }
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/link/create", json=data, headers=headers)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 201

def test_add_balance(merchant_id, user_id, token):
    print_section("Testing Add Balance")
    data = {
        "merchant_id": merchant_id,
        "user_id": user_id,
        "amount": 1000.0
    }
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/link/add-balance", json=data, headers=headers)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_purchase(merchant_id, user_id, token):
    print_section("Testing Purchase")
    data = {
        "merchant_id": merchant_id,
        "user_id": user_id,
        "amount": 100.0,
        "pin": "1234"
    }
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/link/purchase", json=data, headers=headers)
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def main():
    print("\n🧪 MEWallet API Test Suite")
    print("="*50)
    
    # Test health
    if not test_health():
        print("\n❌ Health check failed. Is the server running?")
        return
    
    # Test merchant registration
    merchant_data = test_merchant_registration()
    if not merchant_data:
        print("\n❌ Merchant registration failed")
        return
    
    merchant_id = merchant_data.get("merchant_id")
    merchant_token = merchant_data.get("access_token")
    
    # Test user registration
    user_data = test_user_registration()
    if not user_data:
        print("\n❌ User registration failed")
        return
    
    user_id = user_data.get("user_id")
    
    # Test create link
    if not test_create_link(merchant_id, user_id, merchant_token):
        print("\n❌ Link creation failed")
        return
    
    # Test add balance
    if not test_add_balance(merchant_id, user_id, merchant_token):
        print("\n❌ Add balance failed")
        return
    
    # Test purchase
    if not test_purchase(merchant_id, user_id, merchant_token):
        print("\n❌ Purchase failed")
        return
    
    print("\n" + "="*50)
    print("✅ All tests passed successfully!")
    print("="*50)
    print(f"\nTest Merchant ID: {merchant_id}")
    print(f"Test User ID: {user_id}")
    print("\nYou can now use these IDs to test the mobile app!")

if __name__ == "__main__":
    try:
        main()
    except requests.exceptions.ConnectionError:
        print("\n❌ Cannot connect to the server.")
        print("Make sure the backend is running at http://localhost:8000")
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
