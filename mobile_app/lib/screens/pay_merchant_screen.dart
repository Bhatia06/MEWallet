import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../utils/theme.dart';
import '../models/models.dart';

class PayMerchantScreen extends StatefulWidget {
  final MerchantUserLink link;

  const PayMerchantScreen({super.key, required this.link});

  @override
  State<PayMerchantScreen> createState() => _PayMerchantScreenState();
}

class _PayMerchantScreenState extends State<PayMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());

    // Check if payment will result in negative balance
    final willBeNegative =
        widget.link.balance < 0 || widget.link.balance < amount;
    if (willBeNegative) {
      final balanceAfter = widget.link.balance - amount;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.errorColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Negative Balance Warning',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.link.balance < 0)
                  Text(
                    'Your balance is already negative.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'You will ${widget.link.balance < 0 ? "increase" : "enter"} negative balance of ₹${(-balanceAfter).toStringAsFixed(2)}.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current balance: ₹${widget.link.balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                  ),
                ),
                Text(
                  'Amount to pay: ₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                  ),
                ),
                Text(
                  'Balance after: ₹${balanceAfter.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to continue?',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      final amount = double.parse(_amountController.text.trim());
      await walletProvider.processPurchase(
        merchantId: widget.link.merchantId,
        userId: authProvider.userId!,
        amount: amount,
        pin: _pinController.text,
        token: authProvider.token!,
      );

      if (mounted) {
        // Play voice notification
        TtsService().announcePaymentMade(
          amount: amount,
          merchantName: widget.link.storeName ?? 'Merchant',
          userType: 'user',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment successful!'),
              backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Merchant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.shopping_cart,
                  size: 80, color: AppTheme.successColor),
              const SizedBox(height: 30),
              Text(
                'Pay to Merchant',
                style: AppTheme.headingLarge.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF5F5DC)
                      : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Pay to ${widget.link.storeName ?? widget.link.merchantId}',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE5E5CC)
                      : AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (widget.link.balance < 0
                          ? AppTheme.errorColor
                          : AppTheme.successColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (widget.link.balance < 0
                            ? AppTheme.errorColor
                            : AppTheme.successColor)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: widget.link.balance < 0
                            ? AppTheme.errorColor
                            : AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(
                      'Current Balance: ₹${widget.link.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.link.balance < 0
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Enter your PIN:',
                style: AppTheme.headingSmall.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF5F5DC)
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Pinput(
                controller: _pinController,
                length: 4,
                obscureText: true,
                defaultPinTheme: PinTheme(
                  width: 60,
                  height: 60,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3a3d4a)
                        : Colors.white,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF5a5d6a)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'PIN is required';
                  if (v.length < 4) return 'PIN must be 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the PIN you set for this merchant.',
                style: TextStyle(color: AppTheme.warningColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Payment',
                        style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
