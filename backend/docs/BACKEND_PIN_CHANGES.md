# Backend PIN Implementation - Complete Changes

## Summary
Migrated PIN storage from `merchant_user_links` table to `users` table. Users now have a single 4-digit PIN that is used for all merchant transactions and account operations.

## Database Changes

### Schema Updates (migration_add_pin.sql)
1. **Added to `users` table:**
   - `pin` (TEXT) - Stores hashed 4-digit PIN
   - Index on `pin` for faster lookups
   - `phone` set to NOT NULL with UNIQUE constraint

2. **Removed from `merchant_user_links` table:**
   - `pin` column (no longer needed)

### Migration Steps
Run the following SQL in Supabase SQL Editor:
```sql
-- See backend/migration_add_pin.sql for complete migration script
```

## Backend Code Changes

### 1. utils.py
**Added Functions:**
- `hash_pin(pin: str) -> str` - Hash a 4-digit PIN using bcrypt
- `verify_pin(plain_pin: str, hashed_pin: str) -> bool` - Verify PIN against hash

### 2. models.py
**Updated Models:**
- `UserCreate`:
  - Added required field: `phone` (10 digits, validated)
  - Added required field: `pin` (4 digits, validated)
  - Validators ensure proper format

- `UserCompleteProfile` (new model):
  - For existing users to add phone + PIN
  - Fields: user_id, phone, pin

- `MerchantUserLink`:
  - Comment updated: PIN now verified from users table, not stored here
  - Still accepts `pin` in request for verification purposes

### 3. user_routes.py

**Updated Endpoints:**

#### POST /user/register
- **Changed:** Now requires `phone` and `pin` fields
- **Validation:** 
  - Phone must be 10 digits
  - PIN must be 4 digits
  - Phone must be unique
- **Behavior:** 
  - Hashes PIN before storage
  - Sets `profile_completed = TRUE` when phone + PIN provided
  - Returns user info with access token

#### POST /user/login  
- **Changed:** Now returns profile completion status
- **Response includes:**
  - `profile_completed` (boolean)
  - `needs_phone` (boolean)
  - `needs_pin` (boolean)
- **Use case:** Frontend checks these flags and redirects to complete-profile if needed

#### POST /user/complete-profile (NEW)
- **Purpose:** Allows existing users to complete their profile
- **Request:**
  ```json
  {
    "user_id": "string",
    "phone": "1234567890",
    "pin": "1234"
  }
  ```
- **Validation:**
  - User can only update their own profile
  - Phone must be unique
  - PIN must be 4 digits
- **Behavior:**
  - Hashes PIN
  - Updates phone and pin in users table
  - Sets `profile_completed = TRUE`

### 4. transaction_routes.py

**Updated Endpoints:**

#### POST /link/create
- **Changed:** Now verifies user's PIN from `users` table instead of creating new PIN
- **Validation:**
  - User must have `profile_completed = TRUE`
  - PIN must match user's stored PIN in `users` table
- **Behavior:**
  - Verifies user's PIN using `verify_pin()`
  - Creates link WITHOUT storing PIN (PIN only in users table)
  - Link record only contains: merchant_id, user_id, balance

#### POST /link/delink
- **Changed:** Verifies PIN from `users` table instead of `merchant_user_links`
- **Behavior:**
  - Fetches user's PIN from `users` table
  - Verifies PIN using `verify_pin()`
  - Deletes link if PIN is correct

#### POST /link/purchase
- **Changed:** Verifies PIN from `users` table instead of `merchant_user_links`
- **Behavior:**
  - Fetches user's PIN from `users` table
  - Verifies PIN using `verify_pin()`
  - Processes transaction if PIN is correct

#### POST /link/add-balance
- **No changes needed** - This endpoint doesn't require PIN verification

## Security Improvements

1. **Single Source of Truth:** PIN stored only in `users` table
2. **Consistent Hashing:** All PINs hashed using bcrypt (same as passwords)
3. **Profile Validation:** Links cannot be created until user completes profile
4. **Phone Uniqueness:** Each phone number can only be registered once

## API Response Changes

### Login Response (Before)
```json
{
  "message": "Login successful",
  "user_id": "abc123",
  "user_name": "John",
  "access_token": "...",
  "token_type": "bearer"
}
```

### Login Response (After)
```json
{
  "message": "Login successful",
  "user_id": "abc123",
  "user_name": "John",
  "access_token": "...",
  "token_type": "bearer",
  "profile_completed": true,
  "needs_phone": false,
  "needs_pin": false
}
```

## Error Messages

### New Error Scenarios
1. **Incomplete Profile on Link Creation:**
   - Status: 400 Bad Request
   - Message: "User must complete profile before linking merchant"

2. **Missing PIN:**
   - Status: 400 Bad Request
   - Message: "User PIN not found. Please complete your profile first."

3. **Profile Completion for Another User:**
   - Status: 403 Forbidden
   - Message: "Cannot complete profile for another user"

## Migration Checklist

- [x] Run migration_add_pin.sql in Supabase
- [x] Update utils.py with hash_pin/verify_pin
- [x] Update models.py with new fields and validators
- [x] Update user_routes.py registration endpoint
- [x] Add complete-profile endpoint
- [x] Update login to return profile status
- [x] Update link/create to verify user PIN
- [x] Update link/delink to verify user PIN
- [x] Update link/purchase to verify user PIN
- [ ] Test registration with new phone+PIN requirements
- [ ] Test profile completion flow
- [ ] Test merchant linking with PIN verification
- [ ] Test transactions with PIN verification

## Testing Recommendations

1. **Test User Registration:**
   ```bash
   curl -X POST http://localhost:8000/user/register \
     -H "Content-Type: application/json" \
     -d '{"user_name":"test","user_passw":"password","phone":"9876543210","pin":"1234"}'
   ```

2. **Test Complete Profile:**
   ```bash
   curl -X POST http://localhost:8000/user/complete-profile \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"user_id":"YOUR_ID","phone":"9876543210","pin":"1234"}'
   ```

3. **Test Link Merchant:**
   ```bash
   curl -X POST http://localhost:8000/link/create \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"merchant_id":"M123","user_id":"U123","pin":"1234"}'
   ```

## Breaking Changes

⚠️ **IMPORTANT:** These changes are breaking for existing implementations:

1. **User Registration:** Now requires `phone` and `pin` fields
2. **Merchant Links:** Existing links in database may have PIN in wrong table
3. **API Responses:** Login response now includes additional fields
4. **Database Schema:** merchant_user_links.pin column will be removed

## Rollback Plan

If issues occur, you can rollback by:
1. Restoring the previous database schema
2. Reverting code changes in Git
3. Running: `git checkout HEAD~1 backend/`
