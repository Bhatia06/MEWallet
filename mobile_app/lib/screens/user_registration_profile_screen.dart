import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'user_dashboard_screen.dart';

class UserRegistrationProfileScreen extends StatefulWidget {
  final String userName;
  final String password;

  const UserRegistrationProfileScreen({
    super.key,
    required this.userName,
    required this.password,
  });

  @override
  State<UserRegistrationProfileScreen> createState() =>
      _UserRegistrationProfileScreenState();
}

class _UserRegistrationProfileScreenState
    extends State<UserRegistrationProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _otpVerified = false;
  bool _isSendingOTP = false;
  int _resendTimer = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
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

  Future<void> _handleComplete() async {
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

    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 4-digit PIN'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.registerUser(
        userName: widget.userName,
        password: widget.password,
        phone: _phoneController.text.trim(),
        pin: _pinController.text,
      );

      if (mounted) {
        // Show user ID
        final userId = authProvider.userId;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your User ID is:'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    userId ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please save this ID. You will need it to login.',
                  style: TextStyle(color: AppTheme.errorColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UserDashboardScreen()),
                  );
                },
                child: const Text('Continue'),
              ),
            ],
          ),
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
        title: const Text('Complete Your Profile'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
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
                  const Icon(Icons.badge,
                      size: 80, color: AppTheme.primaryColor),
                  const SizedBox(height: 30),
                  Text(
                    'Complete Your Profile',
                    style: AppTheme.headingLarge.copyWith(
                      color: isDark
                          ? const Color(0xFFF5F5DC)
                          : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add phone number and PIN to complete registration',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDark
                          ? const Color(0xFFE5E5CC)
                          : AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
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
                            hintText: '1234567890',
                            suffixIcon: _otpVerified
                                ? const Icon(Icons.check_circle,
                                    color: AppTheme.successColor)
                                : null,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Phone number is required';
                            }
                            if (v.length < 10) {
                              return 'Phone number must be at least 10 digits';
                            }
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
                  const SizedBox(height: 30),
                  Text(
                    'Create 4-Digit PIN',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF5F5DC)
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Pinput(
                    controller: _pinController,
                    length: 4,
                    obscureText: true,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border:
                            Border.all(color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'PIN is required';
                      if (v.length != 4) return 'PIN must be 4 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This PIN will be used to verify purchases',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Registration',
                            style: TextStyle(fontSize: 18)),
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
