# MEWallet Backend - Complete Test Suite

## 📊 Test Suite Overview

A comprehensive test suite has been created to validate all API endpoints in the MEWallet backend.

### Test Statistics
- **Total Test Files**: 5
- **Estimated Test Cases**: 60+
- **Coverage Target**: > 80%
- **Test Types**: Unit, Integration, Authentication

---

## 📁 Test Files Created

### 1. `tests/conftest.py` - Shared Fixtures
**Purpose**: Provides reusable test fixtures and setup/teardown logic

**Fixtures**:
- `client` - FastAPI TestClient for API requests
- `supabase` - Supabase database client
- `test_user` - Creates test user with auto-cleanup
- `test_merchant` - Creates test merchant with auto-cleanup
- `user_token` - JWT authentication token for users
- `merchant_token` - JWT authentication token for merchants
- `test_link` - Creates merchant-user link with PIN

**Key Features**:
- Automatic cleanup after each test
- Realistic test data using Faker library
- Isolated test environment

---

### 2. `tests/test_user_routes.py` - User API Tests
**Endpoints Tested**: `/user/*`

**Test Classes**:

#### TestUserRegistration
- ✅ `test_register_user_success` - Valid registration
- ✅ `test_register_user_missing_name` - Validation error
- ✅ `test_register_user_missing_password` - Validation error

#### TestUserLogin
- ✅ `test_login_user_success` - Valid credentials
- ✅ `test_login_user_invalid_password` - Wrong password
- ✅ `test_login_user_nonexistent` - User not found
- ✅ `test_login_user_missing_credentials` - Validation error

#### TestUserProfile
- ✅ `test_get_user_profile_success` - Authorized access
- ✅ `test_get_user_profile_unauthorized` - No token
- ✅ `test_get_user_profile_wrong_user` - Forbidden access

#### TestLinkedMerchants
- ✅ `test_get_linked_merchants_success` - Get linked merchants
- ✅ `test_get_linked_merchants_unauthorized` - No token
- ✅ `test_get_linked_merchants_empty` - Empty list

**Total Tests**: 12+

---

### 3. `tests/test_merchant_routes.py` - Merchant API Tests
**Endpoints Tested**: `/merchant/*`

**Test Classes**:

#### TestMerchantRegistration
- ✅ `test_register_merchant_success` - Valid registration
- ✅ `test_register_merchant_duplicate_phone` - Duplicate error
- ✅ `test_register_merchant_missing_fields` - Validation error
- ✅ `test_register_merchant_invalid_phone` - Invalid input

#### TestMerchantLogin
- ✅ `test_login_merchant_success` - Valid credentials
- ✅ `test_login_merchant_invalid_password` - Wrong password
- ✅ `test_login_merchant_nonexistent` - Not found
- ✅ `test_login_merchant_missing_credentials` - Validation error

#### TestMerchantProfile
- ✅ `test_get_merchant_profile_success` - Authorized access
- ✅ `test_get_merchant_profile_unauthorized` - No token
- ✅ `test_get_merchant_profile_wrong_merchant` - Forbidden

#### TestLinkedUsers
- ✅ `test_get_linked_users_success` - Get linked users
- ✅ `test_get_linked_users_unauthorized` - No token
- ✅ `test_get_linked_users_empty` - Empty list

**Total Tests**: 13+

---

### 4. `tests/test_transaction_routes.py` - Transaction API Tests
**Endpoints Tested**: `/link/*`

**Test Classes**:

#### TestCreateLink
- ✅ `test_create_link_success` - Valid link creation
- ✅ `test_create_link_invalid_pin` - PIN validation
- ✅ `test_create_link_duplicate` - Duplicate prevention
- ✅ `test_create_link_merchant_not_found` - Not found error
- ✅ `test_create_link_unauthorized` - No token

#### TestAddBalance
- ✅ `test_add_balance_success` - Valid balance addition
- ✅ `test_add_balance_invalid_pin` - Wrong PIN
- ✅ `test_add_balance_negative_amount` - Validation error
- ✅ `test_add_balance_exceeds_limit` - Limit checking

#### TestProcessPurchase
- ✅ `test_purchase_success` - Valid purchase
- ✅ `test_purchase_insufficient_balance` - Balance check
- ✅ `test_purchase_invalid_pin` - Wrong PIN
- ✅ `test_purchase_negative_amount` - Validation error

#### TestGetBalance
- ✅ `test_get_balance_success` - Get current balance
- ✅ `test_get_balance_unauthorized` - No token

#### TestGetTransactions
- ✅ `test_get_merchant_user_transactions` - Transaction history
- ✅ `test_get_user_transactions` - User's all transactions
- ✅ `test_get_transactions_unauthorized` - No token

**Total Tests**: 17+

---

### 5. `tests/test_pay_request_routes.py` - Pay Request Tests
**Endpoints Tested**: `/pay-requests/*`

**Test Classes**:

#### TestCreatePayRequest
- ✅ `test_create_pay_request_success` - Valid creation
- ✅ `test_create_pay_request_no_link` - No link error
- ✅ `test_create_pay_request_negative_amount` - Validation
- ✅ `test_create_pay_request_unauthorized` - No token

#### TestGetUserPayRequests
- ✅ `test_get_user_pay_requests_success` - Get requests
- ✅ `test_get_user_pay_requests_unauthorized` - No token
- ✅ `test_get_user_pay_requests_wrong_user` - Forbidden

#### TestGetMerchantPayRequests
- ✅ `test_get_merchant_pay_requests_success` - Get requests
- ✅ `test_get_merchant_pay_requests_unauthorized` - No token

#### TestAcceptPayRequest
- ✅ `test_accept_pay_request_success` - Valid acceptance
- ✅ `test_accept_pay_request_invalid_pin` - Wrong PIN
- ✅ `test_accept_pay_request_insufficient_balance` - Balance check

#### TestRejectPayRequest
- ✅ `test_reject_pay_request_success` - Valid rejection
- ✅ `test_reject_pay_request_not_found` - Not found error
- ✅ `test_reject_pay_request_unauthorized` - No token

**Total Tests**: 14+

---

### 6. `tests/test_oauth_routes.py` - OAuth Tests
**Endpoints Tested**: `/oauth/*`

**Test Classes**:

#### TestGoogleOAuth
- ✅ `test_oauth_register_user_success` - OAuth user registration
- ✅ `test_oauth_register_merchant_success` - OAuth merchant registration
- ✅ `test_oauth_login_existing_user` - Login with OAuth
- ✅ `test_oauth_invalid_token` - Invalid token handling
- ✅ `test_oauth_invalid_user_type` - Validation error

#### TestCompleteMerchantProfile
- ✅ `test_complete_merchant_profile_success` - Complete profile
- ✅ `test_complete_merchant_profile_unauthorized` - No token
- ✅ `test_complete_merchant_profile_wrong_merchant` - Forbidden

#### TestCompleteUserProfile
- ✅ `test_complete_user_profile_success` - Complete profile
- ✅ `test_complete_user_profile_unauthorized` - No token
- ✅ `test_complete_user_profile_missing_fields` - Validation

**Note**: OAuth tests use mocked Google token verification

**Total Tests**: 11+

---

## 🚀 Running the Tests

### Quick Start

```bash
# Navigate to backend directory
cd backend

# Install test dependencies (if not already installed)
pip install -r requirements.txt

# Run all tests
pytest

# Run with coverage report
pytest --cov=. --cov-report=html
```

### Using the Test Runner Script

```bash
# Run interactive test menu
python run_tests.py
```

**Menu Options**:
1. Run all tests with coverage
2. Run user routes tests only
3. Run merchant routes tests only
4. Run transaction routes tests only
5. Run pay request routes tests only
6. Run OAuth routes tests only
7. Run with debugger (pdb)
8. Run last failed tests only
9. Show HTML coverage report

### Command Line Options

```bash
# Run specific test file
pytest tests/test_user_routes.py

# Run specific test class
pytest tests/test_user_routes.py::TestUserRegistration

# Run specific test function
pytest tests/test_user_routes.py::TestUserRegistration::test_register_user_success

# Run with verbose output
pytest -v

# Run with detailed output
pytest -vv

# Run with print statements
pytest -s

# Run only failed tests from last run
pytest --lf

# Run with debugger on failure
pytest --pdb

# Run with coverage
pytest --cov=. --cov-report=term-missing
```

---

## 📊 Coverage Report

### How to Generate Coverage

```bash
# Generate terminal report
pytest --cov=. --cov-report=term-missing

# Generate HTML report
pytest --cov=. --cov-report=html

# Open HTML report (will be in htmlcov/index.html)
```

### Expected Coverage
- **User Routes**: ~90%
- **Merchant Routes**: ~90%
- **Transaction Routes**: ~85%
- **Pay Request Routes**: ~85%
- **OAuth Routes**: ~75%
- **Overall Target**: > 80%

---

## 🔧 Configuration Files

### `pytest.ini`
- Test discovery patterns
- Output formatting
- Coverage settings
- Test markers

### `.coveragerc`
- Coverage source paths
- Files to omit from coverage
- HTML report settings
- Exclusion patterns

### `requirements.txt`
Updated with test dependencies:
- `pytest==7.4.3`
- `pytest-cov==4.1.0`
- `pytest-asyncio==0.21.1`
- `faker==20.1.0`
- `httpx==0.25.2`

---

## 🎯 Test Categories

### Unit Tests
- Individual function testing
- Validation logic
- Error handling

### Integration Tests
- API endpoint testing
- Database operations
- Authentication flow

### Security Tests
- Authorization checks
- Token validation
- Resource ownership

---

## ✅ What's Being Tested

### Authentication & Authorization
- User registration and login
- Merchant registration and login
- OAuth Google Sign-In
- JWT token generation
- Token-based authorization
- Resource ownership verification

### Business Logic
- Link creation between merchants and users
- Balance management (add/subtract)
- Purchase transactions
- Pay request workflow
- Profile completion

### Data Validation
- Required fields
- Field formats (PIN, phone, amounts)
- Duplicate prevention
- Negative amount checks
- Balance limits

### Error Handling
- Invalid credentials
- Unauthorized access
- Not found errors
- Validation errors
- Duplicate resource errors

### Edge Cases
- Empty result sets
- Insufficient balance
- Wrong PIN attempts
- Missing fields
- Invalid tokens

---

## 🐛 Debugging Tests

### Common Issues

**Issue**: Tests fail with database connection error
```bash
Solution: Check .env file has correct SUPABASE_URL and SUPABASE_KEY
```

**Issue**: Import errors
```bash
Solution: Ensure you're in the backend directory and virtual env is activated
```

**Issue**: Fixture not found
```bash
Solution: Check conftest.py is in tests/ directory
```

**Issue**: Tests pass locally but fail in CI
```bash
Solution: Check environment variables are set in CI configuration
```

### Debug Commands

```bash
# Show which tests will run
pytest --collect-only

# Run with maximum verbosity
pytest -vvv

# Show local variables on failure
pytest -l

# Drop into debugger on first failure
pytest -x --pdb

# Run specific test with output
pytest tests/test_user_routes.py::TestUserLogin::test_login_user_success -s
```

---

## 📈 CI/CD Integration

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.10'
    
    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements.txt
    
    - name: Run tests
      run: |
        cd backend
        pytest --cov=. --cov-report=xml
      env:
        SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
        SUPABASE_KEY: ${{ secrets.SUPABASE_KEY }}
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
```

---

## 🎓 Best Practices Followed

1. **Test Isolation**: Each test is independent
2. **Automatic Cleanup**: Fixtures handle data cleanup
3. **Realistic Data**: Using Faker for test data
4. **Clear Naming**: Descriptive test function names
5. **Documentation**: Docstrings for all tests
6. **Coverage**: Both success and failure paths
7. **Security**: Mocking external services
8. **Maintainability**: Reusable fixtures

---

## 📚 Additional Resources

### Documentation
- [pytest Documentation](https://docs.pytest.org/)
- [pytest-cov Documentation](https://pytest-cov.readthedocs.io/)
- [Faker Documentation](https://faker.readthedocs.io/)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

### Test Files Location
```
backend/
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_user_routes.py
│   ├── test_merchant_routes.py
│   ├── test_transaction_routes.py
│   ├── test_pay_request_routes.py
│   └── test_oauth_routes.py
├── pytest.ini
├── .coveragerc
└── run_tests.py
```

---

## ✨ Next Steps

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Run Tests**:
   ```bash
   pytest -v
   ```

3. **Check Coverage**:
   ```bash
   pytest --cov=. --cov-report=html
   open htmlcov/index.html
   ```

4. **Review Results**: Fix any failing tests

5. **Iterate**: Add more tests as needed

---

**Created**: December 2024  
**Test Framework**: pytest 7.4.3  
**Coverage Goal**: > 80%  
**Total Test Cases**: 60+

Happy Testing! 🧪✅
