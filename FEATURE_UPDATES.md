# Feature Updates Summary

## Overview
All requested features have been successfully implemented:

1. ✅ Removed link merchant and purchase from user dashboard
2. ✅ Added delink with PIN confirmation for users
3. ✅ Added backend delink endpoint
4. ✅ Added PIN verification for add balance operation
5. ✅ Added merchant purchase/deduct with PIN
6. ✅ Implemented dark mode theme
7. ✅ Added dark mode toggle to all screens

---

## 1. User Restrictions (View-Only with Delink)

### Changes Made:
- **Removed**: FloatingActionButton for "Link Merchant" from user dashboard
- **Removed**: Import for `link_merchant_screen.dart` (users can no longer navigate to it)
- **Added**: Delink button on each merchant card with PIN verification
- **Flow**: User clicks "Delink" → Enters PIN → Confirms action → Link removed

### Files Modified:
- `mobile_app/lib/screens/user_dashboard_screen.dart`
  - Removed FAB for linking merchants
  - Added delink button in merchant card trailing section
  - Added `_showDelinkDialog()` - PIN entry dialog
  - Added `_confirmDelink()` - Confirmation dialog
  - Added `_performDelink()` - API call to delink

- `mobile_app/lib/providers/wallet_provider.dart`
  - Added `delinkMerchant()` method

- `mobile_app/lib/services/api_service.dart`
  - Added `delinkMerchant()` API method

---

## 2. Backend Delink Endpoint

### New Endpoint:
```
POST /link/delink
```

### Request Body:
```json
{
  "merchant_id": "MR123456",
  "user_id": "UR123456",
  "amount": 0.0,  // Required by ProcessTransaction model but not used
  "pin": "1234"
}
```

### Response:
```json
{
  "message": "Successfully delinked",
  "merchant_id": "MR123456",
  "user_id": "UR123456"
}
```

### Implementation:
- Verifies PIN matches the stored hashed PIN
- Deletes the merchant_user_link record
- Preserves transaction history (transactions are not deleted)

### Files Modified:
- `backend/transaction_routes.py`
  - Added `/link/delink` endpoint with PIN verification

---

## 3. PIN Verification for Add Balance

### Changes Made:
- **Backend**: Updated `AddBalance` model to require PIN field
- **Backend**: Modified `/link/add-balance` endpoint to verify PIN before adding balance
- **Frontend**: Added PIN entry dialog before confirming balance addition
- **Flow**: Merchant enters amount → Enters PIN → Balance added

### Files Modified:
- `backend/models.py`
  - Updated `AddBalance` class to include `pin` field with 4-6 digit validation

- `backend/transaction_routes.py`
  - Added PIN verification in `add_balance()` function
  - Returns 401 error if PIN is invalid

- `mobile_app/lib/screens/transaction_detail_screen.dart`
  - Modified `_showAddBalanceDialog()` to show Continue button
  - Added `_showPinDialog()` for PIN entry
  - Updated `_addBalance()` to accept PIN parameter

- `mobile_app/lib/providers/wallet_provider.dart`
  - Updated `addBalance()` to include PIN parameter

- `mobile_app/lib/services/api_service.dart`
  - Updated `addBalance()` to send PIN in request body

---

## 4. Merchant Purchase/Deduct Feature

### Changes Made:
- **Added**: PopupMenu button on each user card in merchant dashboard
- **Options**: 
  - "Add Balance" → Navigates to transaction detail screen (existing flow)
  - "Make Purchase" → New feature to deduct balance with PIN
- **Flow**: Merchant selects user → "Make Purchase" → Enters amount → Enters PIN → Balance deducted

### Files Modified:
- `mobile_app/lib/screens/merchant_dashboard_screen.dart`
  - Replaced simple trailing widget with Row containing balance + PopupMenuButton
  - Added `_showPurchaseDialog()` - Amount entry dialog
  - Added `_showPurchasePinDialog()` - PIN entry dialog
  - Added `_performPurchase()` - Calls existing `processPurchase` API

### Backend:
- Uses existing `/link/purchase` endpoint (no changes needed)
- Verifies PIN and deducts amount from balance
- Records transaction as "debit" type

---

## 5. Dark Mode Implementation

### Theme Files:
- **Created**: `mobile_app/lib/providers/theme_provider.dart`
  - Manages theme state (light/dark/system)
  - Persists preference using StorageService
  - Provides `toggleTheme()` method

- **Updated**: `mobile_app/lib/utils/theme.dart`
  - Added `darkTheme` ThemeData with dark colors
  - Dark background: `#121212`
  - Dark cards: `#1E1E1E`
  - Dark input fields: `#2A2A2A`

### Main App Integration:
- **Updated**: `mobile_app/lib/main.dart`
  - Added ThemeProvider to MultiProvider
  - Wrapped MaterialApp with Consumer<ThemeProvider>
  - Set `theme`, `darkTheme`, and `themeMode` properties

### Dashboard Integration:
- **Updated**: Both dashboard screens
  - Added import for `theme_provider.dart`
  - Added IconButton in AppBar for theme toggle
  - Icon changes based on current theme (sun for dark mode, moon for light mode)
  - Calls `context.read<ThemeProvider>().toggleTheme()` on press

### Files Modified:
- `mobile_app/lib/providers/theme_provider.dart` (NEW)
- `mobile_app/lib/utils/theme.dart`
- `mobile_app/lib/main.dart`
- `mobile_app/lib/screens/merchant_dashboard_screen.dart`
- `mobile_app/lib/screens/user_dashboard_screen.dart`

---

## API Changes Summary

### New Endpoint:
1. **POST /link/delink**
   - Purpose: Remove merchant-user link
   - Requires: merchant_id, user_id, pin
   - Auth: JWT token required

### Modified Endpoints:
1. **POST /link/add-balance**
   - Added: `pin` field (required)
   - Validates PIN before adding balance

### Existing Endpoints Used:
1. **POST /link/purchase** (used by new merchant purchase feature)
   - No changes needed

---

## User Experience Flow

### For Users:
1. **View Merchants**: See all linked merchants with balances
2. **Delink**: 
   - Click "Delink" button on merchant card
   - Enter PIN
   - Confirm action
   - Link removed (transaction history preserved)
3. **Dark Mode**: Toggle in app bar (top right)

### For Merchants:
1. **View Users**: See all linked users with balances
2. **Add Balance**:
   - Click user card → Transaction screen
   - Click "Add Balance" FAB
   - Enter amount
   - Enter PIN
   - Balance added
3. **Make Purchase**:
   - Click menu (3 dots) on user card
   - Select "Make Purchase"
   - Enter amount
   - Enter PIN
   - Balance deducted
4. **Link Users**: Use FAB to add new users (existing flow)
5. **Dark Mode**: Toggle in app bar (top right)

---

## Security Notes

1. All PIN operations require hash verification on backend
2. Delink operation preserves transaction history for audit trail
3. Add balance now requires PIN (prevents unauthorized additions)
4. Purchase operations already had PIN requirement (no change)

---

## Testing Checklist

### Backend:
- [ ] Test delink endpoint with correct PIN
- [ ] Test delink endpoint with wrong PIN (should return 401)
- [ ] Test add balance with correct PIN
- [ ] Test add balance with wrong PIN (should return 401)

### Frontend:
- [ ] Test user delink flow (PIN entry + confirmation)
- [ ] Test merchant add balance with PIN
- [ ] Test merchant purchase/deduct with PIN
- [ ] Test dark mode toggle on both dashboards
- [ ] Verify theme persists after app restart

### Edge Cases:
- [ ] Delink when balance > 0 (allowed)
- [ ] Purchase when amount > balance (should show error)
- [ ] PIN with < 4 or > 6 digits (should show validation error)

---

## Next Steps to Run

1. **Backend**: Restart the server to load new endpoint
   ```powershell
   cd backend
   .\.venv\Scripts\Activate.ps1
   python main.py
   ```

2. **Frontend**: Run flutter analyze and test
   ```powershell
   cd mobile_app
   flutter analyze
   flutter run -d chrome
   ```

3. **Test**: Create test merchant and user, link them, test all new features

---

## Notes

- All transaction history is preserved even after delinking
- Dark mode preference is saved locally and persists across sessions
- Users can only delink (cannot link or purchase themselves)
- Merchants have full control (link, add balance, deduct balance)
- PIN verification protects all balance operations
