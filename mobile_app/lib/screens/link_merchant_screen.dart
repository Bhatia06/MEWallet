import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class LinkMerchantScreen extends StatefulWidget {
  const LinkMerchantScreen({super.key});

  @override
  State<LinkMerchantScreen> createState() => _LinkMerchantScreenState();
}

class _LinkMerchantScreenState extends State<LinkMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantIdController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _merchantIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkMerchant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.createLink(
        merchantId: _merchantIdController.text.trim(),
        userId: authProvider.userId!,
        pin: _pinController.text,
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Merchant linked successfully!'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link Merchant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 30),
              Text(
                'Link with Merchant',
                style: AppTheme.headingLarge.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF5F5DC)
                      : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Enter your PIN to make purchases at this merchant',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE5E5CC)
                      : AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _merchantIdController,
                decoration: const InputDecoration(
                  labelText: 'Merchant ID',
                  hintText: 'MRxxxxxx',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Merchant ID is required' : null,
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
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLinkMerchant,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Link Merchant',
                        style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
