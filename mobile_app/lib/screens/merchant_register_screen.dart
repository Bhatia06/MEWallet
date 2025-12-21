import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'merchant_dashboard_screen.dart';
import 'user_dashboard_screen.dart';
import 'merchant_oauth_profile_screen.dart';

class MerchantRegisterScreen extends StatefulWidget {
  const MerchantRegisterScreen({super.key});

  @override
  State<MerchantRegisterScreen> createState() => _MerchantRegisterScreenState();
}

class _MerchantRegisterScreenState extends State<MerchantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _isSendingOTP = false;
  int _resendTimer = 0;

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.trim().isEmpty ||
        _phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSendingOTP = true);

    try {
      // First check if phone number already exists
      final checkResult = await ApiService().checkPhoneExists(
        phone: _phoneController.text.trim(),
      );

      if (mounted && checkResult['exists'] == true) {
        setState(() => _isSendingOTP = false);

        // Show dialog asking to login
        final shouldLogin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Phone Number Exists'),
            content: Text(
              checkResult['message'] ??
                  'This phone number is already registered. Would you like to login instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        );

        if (shouldLogin == true && mounted) {
          // Navigate to login page based on user type
          Navigator.pushNamedAndRemoveUntil(
            context,
            checkResult['user_type'] == 'merchant'
                ? '/merchant-login'
                : '/user-login',
            (route) => false,
          );
        }
        return;
      }

      // Phone doesn't exist, proceed with OTP
      await ApiService().sendOTP(phone: _phoneController.text.trim());

      if (mounted) {
        setState(() {
          _otpSent = true;
          _resendTimer = 60;
        });

        // Start countdown timer
        Future.doWhile(() async {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted && _resendTimer > 0) {
            setState(() => _resendTimer--);
            return true;
          }
          return false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your phone number'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() => _isSendingOTP = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit OTP'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      await ApiService().verifyOTP(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
      );

      if (mounted) {
        setState(() => _otpVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your phone number with OTP'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.registerMerchant(
        storeName: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // Show welcome message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome ${_storeNameController.text.trim()}! Please complete your profile in settings page.',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MerchantDashboardScreen()),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE0E0E0),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Registration'),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.store,
                      size: 80, color: AppTheme.primaryColor),
                  const SizedBox(height: 30),
                  Text(
                    'Create Merchant Account',
                    style: AppTheme.headingLarge.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF5F5DC)
                          : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(
                        labelText: 'Store Name',
                        prefixIcon: Icon(Icons.storefront)),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Store name is required'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_otpVerified,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone),
                            suffixIcon: _otpVerified
                                ? const Icon(Icons.check_circle,
                                    color: AppTheme.successColor)
                                : null,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Phone is required';
                            if (v.length != 10 ||
                                !RegExp(r'^\d{10}$').hasMatch(v))
                              return 'Enter valid 10-digit number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _otpVerified || _isSendingOTP
                            ? null
                            : (_otpSent && _resendTimer > 0 ? null : _sendOTP),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                        child: _isSendingOTP
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _otpSent
                                    ? (_resendTimer > 0
                                        ? 'Resend ($_resendTimer)'
                                        : 'Resend')
                                    : 'Send OTP',
                                style: const TextStyle(fontSize: 14),
                              ),
                      ),
                    ],
                  ),
                  if (_otpSent && !_otpVerified) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Enter 6-Digit OTP',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Pinput(
                      controller: _otpController,
                      length: 6,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: defaultPinTheme.copyWith(
                        decoration: defaultPinTheme.decoration!.copyWith(
                          border: Border.all(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      onCompleted: (_) => _verifyOTP(),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'OTP sent to your phone number',
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: authProvider.isLoading
                        ? const SpinKitThreeBounce(
                            color: Colors.white, size: 20)
                        : const Text('Register',
                            style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            try {
                              final result = await authProvider
                                  .signInWithGoogle(userType: 'merchant');
                              if (mounted) {
                                // Check if account already exists
                                if (result['existing_account'] == true) {
                                  // Show message and navigate to dashboard
                                  final userType = result['user_type'];
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Account already exists as ${userType == 'merchant' ? 'Merchant' : 'User'}. Logging you in...',
                                      ),
                                      backgroundColor: AppTheme.successColor,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );

                                  // Navigate to appropriate dashboard
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => userType == 'merchant'
                                          ? const MerchantDashboardScreen()
                                          : const UserDashboardScreen(),
                                    ),
                                  );
                                } else if (result['needs_profile'] == true) {
                                  // Navigate to profile completion screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MerchantOAuthProfileScreen(
                                        merchantId: result['id'],
                                        ownerName: result['owner_name'],
                                        googleEmail: result['google_email'],
                                        token: result['token'],
                                      ),
                                    ),
                                  );
                                } else {
                                  // Profile already complete, go to dashboard
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MerchantDashboardScreen()),
                                  );
                                }
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e.message),
                                      backgroundColor: AppTheme.errorColor),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.g_mobiledata, size: 32),
                    label: const Text('Continue with Google',
                        style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
