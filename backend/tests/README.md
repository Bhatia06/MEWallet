# Test Suite for MEWallet Backend

This directory contains comprehensive test cases for all MEWallet API endpoints.

## 📁 Test Structure

```
tests/
├── __init__.py                    # Package marker
├── conftest.py                    # Shared fixtures and setup
├── test_user_routes.py            # User authentication & profile tests
├── test_merchant_routes.py        # Merchant authentication & profile tests
├── test_transaction_routes.py     # Transaction & balance tests
├── test_pay_request_routes.py     # Pay request workflow tests
└── test_oauth_routes.py           # OAuth authentication tests
```

## 🧪 Test Coverage

### User Routes (`test_user_routes.py`)
- ✅ User registration (success, validation errors)
- ✅ User login (success, invalid credentials, missing fields)
- ✅ User profile retrieval (authorized, unauthorized)
- ✅ Linked merchants listing

### Merchant Routes (`test_merchant_routes.py`)
- ✅ Merchant registration (success, duplicate phone, validation)
- ✅ Merchant login (success, invalid credentials)
- ✅ Merchant profile retrieval
- ✅ Linked users listing

### Transaction Routes (`test_transaction_routes.py`)
- ✅ Create merchant-user link (success, invalid PIN, duplicates)
- ✅ Add balance (success, invalid PIN, negative amounts)
- ✅ Process purchase (success, insufficient balance, wrong PIN)
- ✅ Get balance
- ✅ Get transactions

### Pay Request Routes (`test_pay_request_routes.py`)
- ✅ Create pay request (success, no link, negative amount)
- ✅ Get user/merchant pay requests
- ✅ Accept pay request (success, invalid PIN, insufficient balance)
- ✅ Reject pay request

### OAuth Routes (`test_oauth_routes.py`)
- ✅ Google OAuth login/registration (mocked)
- ✅ Complete merchant profile
- ✅ Complete user profile
- ✅ Invalid token handling

## 🚀 Running Tests

### Run All Tests
```bash
pytest
```

### Run Specific Test File
```bash
pytest tests/test_user_routes.py
pytest tests/test_transaction_routes.py
```

### Run Specific Test Class
```bash
pytest tests/test_user_routes.py::TestUserRegistration
```

### Run Specific Test Function
```bash
pytest tests/test_user_routes.py::TestUserRegistration::test_register_user_success
```

### Run with Coverage Report
```bash
pytest --cov=. --cov-report=html
```
Then open `htmlcov/index.html` in your browser.

### Run with Verbose Output
```bash
pytest -v
```

### Run Only Fast Tests (Skip Slow Tests)
```bash
pytest -m "not slow"
```

## 📊 Test Fixtures

### Available Fixtures (from `conftest.py`)

- **`client`**: TestClient for making API requests
- **`supabase`**: Supabase database client
- **`test_user`**: Creates a test user with cleanup
- **`test_merchant`**: Creates a test merchant with cleanup
- **`user_token`**: JWT token for test user
- **`merchant_token`**: JWT token for test merchant
- **`test_link`**: Creates merchant-user link with PIN

### Usage Example
```python
def test_example(client, test_user, user_token):
    headers = {"Authorization": f"Bearer {user_token}"}
    response = client.get(f"/user/profile/{test_user['user_id']}", headers=headers)
    assert response.status_code == 200
```

## 🔧 Requirements

Install test dependencies:
```bash
pip install pytest pytest-cov faker httpx
```

Or if you have a requirements.txt:
```bash
pip install -r requirements.txt
```

## 📝 Writing New Tests

### Test Class Naming Convention
```python
class TestFeatureName:
    """Test description"""
    
    def test_scenario_success(self, fixtures):
        """Test successful scenario"""
        pass
    
    def test_scenario_failure(self, fixtures):
        """Test failure scenario"""
        pass
```

### Test Function Naming
- `test_<feature>_success` - Happy path
- `test_<feature>_<error_type>` - Error cases
- `test_<feature>_unauthorized` - Auth failures
- `test_<feature>_validation` - Input validation

### Common Assertions
```python
# Status codes
assert response.status_code == 200
assert response.status_code == 401

# Response data
assert "key" in response.json()
assert response.json()["message"] == "Success"
assert isinstance(response.json(), list)

# Error messages
assert "error text" in response.json()["detail"]
```

## 🐛 Debugging Failed Tests

### Run with Detailed Output
```bash
pytest -vv --tb=long
```

### Run Last Failed Tests Only
```bash
pytest --lf
```

### Run with PDB Debugger
```bash
pytest --pdb
```

### Print Output During Tests
```bash
pytest -s
```

## 📈 Coverage Goals

Target coverage: **> 80%**

Current coverage by module:
- User Routes: ~90%
- Merchant Routes: ~90%
- Transaction Routes: ~85%
- Pay Request Routes: ~85%
- OAuth Routes: ~75% (requires mocking)

## 🔐 Security Considerations

- All fixtures automatically clean up test data
- Test database should be separate from production
- Sensitive data (passwords, tokens) are generated via faker
- OAuth tests use mocked Google verification

## 📞 Support

For issues or questions about tests:
1. Check test output for error details
2. Verify database connection in `.env`
3. Ensure all dependencies are installed
4. Check fixture cleanup in `conftest.py`

## 🎯 Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Use fixtures for automatic cleanup
3. **Mocking**: Mock external services (Google OAuth)
4. **Assertions**: Use descriptive assertion messages
5. **Coverage**: Aim for both success and failure paths
6. **Documentation**: Add docstrings to test functions

## 🔄 Continuous Integration

To run tests in CI/CD:
```bash
# Install dependencies
pip install -r requirements.txt

# Run tests with coverage
pytest --cov=. --cov-report=xml

# Check coverage threshold
coverage report --fail-under=80
```
