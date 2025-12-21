import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../utils/theme.dart';
import '../models/models.dart';

class AcceptPayRequestScreen extends StatefulWidget {
  final PayRequest payRequest;
  final double currentBalance;

  const AcceptPayRequestScreen({
    super.key,
    required this.payRequest,
    required this.currentBalance,
  });

  @override
  State<AcceptPayRequestScreen> createState() => _AcceptPayRequestScreenState();
}

class _AcceptPayRequestScreenState extends State<AcceptPayRequestScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleAcceptPayment() async {
    if (_pinController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your 4-digit PIN'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Check if payment will result in negative balance
    final willBeNegative = widget.currentBalance < widget.payRequest.amount;
    if (willBeNegative) {
      final negativeAmount = widget.payRequest.amount - widget.currentBalance;
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
                Text(
                  'You will enter negative balance of ₹${negativeAmount.toStringAsFixed(2)}.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current balance: ₹${widget.currentBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                  ),
                ),
                Text(
                  'Amount to pay: ₹${widget.payRequest.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                  ),
                ),
                Text(
                  'Balance after: -₹${negativeAmount.toStringAsFixed(2)}',
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
      final result = await walletProvider.apiService.acceptPayRequest(
        requestId: widget.payRequest.id,
        pin: _pinController.text,
        token: authProvider.token!,
      );

      if (mounted) {
        // Play voice notification
        TtsService().announcePaymentMade(
          amount: widget.payRequest.amount,
          merchantName: widget.payRequest.storeName ?? 'Merchant',
          userType: 'user',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Payment successful!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Accept Payment Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.payment, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 30),
            Text(
              'Payment Request',
              style: AppTheme.headingLarge.copyWith(
                color: isDark ? const Color(0xFFF5F5DC) : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'From ${widget.payRequest.storeName ?? widget.payRequest.merchantId}',
              style: AppTheme.bodyMedium.copyWith(
                color:
                    isDark ? const Color(0xFFE5E5CC) : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Pay',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFFE5E5CC)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.payRequest.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252838) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Balance:',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                    ),
                  ),
                  Text(
                    '₹${widget.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.currentBalance < 0
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.payRequest.description != null &&
                widget.payRequest.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF252838) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description:',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.payRequest.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark ? const Color(0xFFF5F5DC) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            Text(
              'Enter your PIN to confirm:',
              style: AppTheme.headingSmall.copyWith(
                color: isDark ? const Color(0xFFF5F5DC) : AppTheme.textPrimary,
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
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3a3d4a) : Colors.white,
                  border: Border.all(
                    color:
                        isDark ? const Color(0xFF5a5d6a) : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter the PIN you set for this merchant.',
              style: TextStyle(color: AppTheme.warningColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleAcceptPayment,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm Payment',
                      style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Cancel', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
