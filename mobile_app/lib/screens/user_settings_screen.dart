import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _googleEmail;
  DateTime? _selectedDob;
  bool _hasPassword = false;
  bool _voiceNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadVoiceNotificationSetting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      print('Loading profile for user: ${authProvider.userId}');
      final profile = await ApiService().getUserProfileDetails(
        userId: authProvider.userId!,
        token: authProvider.token!,
      );

      print('Profile data received: $profile');
      print('Phone: ${profile['phone']}');
      print('Google Email: ${profile['google_email']}');

      if (mounted) {
        setState(() {
          _nameController.text = profile['user_name'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
          // Handle both null and empty string for google_email
          final googleEmail = profile['google_email'];
          _googleEmail =
              (googleEmail != null && googleEmail.toString().isNotEmpty)
                  ? googleEmail.toString()
                  : null;

          if (profile['dob'] != null) {
            _selectedDob = DateTime.parse(profile['dob']);
            _dobController.text = _formatDate(_selectedDob!);
          }

          _hasPassword = profile['has_password'] ?? false;
          _isLoading = false;
        });
        print('Phone controller text: ${_phoneController.text}');
        print('Google email state: $_googleEmail');
        print('Has password: $_hasPassword');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadVoiceNotificationSetting() async {
    final enabled = await TtsService().isVoiceNotificationEnabled('user');
    if (mounted) {
      setState(() => _voiceNotificationsEnabled = enabled);
    }
  }

  Future<void> _toggleVoiceNotifications(bool value) async {
    await TtsService().setVoiceNotificationEnabled('user', value);
    setState(() => _voiceNotificationsEnabled = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Voice notifications enabled'
                : 'Voice notifications disabled',
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _editPhone() async {
    final phoneController = TextEditingController(text: _phoneController.text);

    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '1234567890',
            prefixIcon: Icon(Icons.phone),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number is required')),
                );
                return;
              }
              if (phone.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid phone number')),
                );
                return;
              }
              Navigator.pop(context, phone);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    phoneController.dispose();

    if (newPhone != null && newPhone != _phoneController.text) {
      setState(() {
        _phoneController.text = newPhone;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await ApiService().updateUserProfile(
        userId: authProvider.userId!,
        token: authProvider.token!,
        userName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: _selectedDob?.toIso8601String().split('T')[0],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      // Sign out first to force account picker to show
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      final authProvider = context.read<AuthProvider>();
      await ApiService().linkGoogleAccount(
        userId: authProvider.userId!,
        token: authProvider.token!,
        idToken: idToken,
      );

      if (mounted) {
        setState(() => _googleEmail = googleUser.email);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account linked successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking Google account: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _setPassword() async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Set Password',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set a password to login with your phone number',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password is required')),
                );
                return;
              }
              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              if (password != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Set Password'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final authProvider = context.read<AuthProvider>();
        await ApiService().setUserPassword(
          userId: authProvider.userId!,
          token: authProvider.token!,
          password: passwordController.text.trim(),
        );

        if (mounted) {
          setState(() => _hasPassword = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Password set successfully! You can now login with your phone number.'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error setting password: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }

    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _updatePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Update Password',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'At least 6 characters',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            onPressed: () {
              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (oldPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Current password is required')),
                );
                return;
              }
              if (newPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New password is required')),
                );
                return;
              }
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('New password must be at least 6 characters')),
                );
                return;
              }
              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final authProvider = context.read<AuthProvider>();
        await ApiService().updateUserPassword(
          userId: authProvider.userId!,
          token: authProvider.token!,
          oldPassword: oldPasswordController.text.trim(),
          newPassword: newPasswordController.text.trim(),
        );

        if (mounted) {
          setState(() => _hasPassword = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().contains('incorrect')
                  ? 'Current password is incorrect'
                  : 'Error updating password: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.\n\nNote: You can only delete your account if all your balances are zero.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      await ApiService().deleteUserAccount(
        userId: authProvider.userId!,
        token: authProvider.token!,
      );

      if (mounted) {
        await authProvider.logout();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Account'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Section
                    Text(
                      'Profile Information',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _editPhone,
                        ),
                      ),
                      onTap: _editPhone,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _selectDate,
                        ),
                      ),
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Password Section
                    Text(
                      'Security',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasPassword
                                  ? 'We reccomend updating your password once a month to be secure'
                                  : 'You can set your password to manually log in with your mobile number',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE5E5CC)
                                    : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _hasPassword ? _updatePassword : _setPassword,
                      icon: Icon(
                          _hasPassword ? Icons.lock_reset : Icons.lock_outline),
                      label: Text(
                          _hasPassword ? 'Update Password' : 'Set Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Google Account Section
                    Text(
                      'Google Account',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_googleEmail != null) ...[
                      ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: AppTheme.successColor),
                        title: const Text('Linked to Google'),
                        subtitle: Text(_googleEmail!),
                        tileColor: AppTheme.successColor.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _linkGoogleAccount,
                        icon: const Icon(Icons.link),
                        label: const Text('Link Google Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Appearance Section
                    Text(
                      'Appearance',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return SwitchListTile(
                          title: const Text('Dark Mode'),
                          subtitle: const Text('Toggle dark/light theme'),
                          value: isDark,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          secondary:
                              Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                          tileColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Notifications Section
                    Text(
                      'Notifications',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Voice Notifications'),
                      subtitle: const Text('Hear payment and balance updates'),
                      value: _voiceNotificationsEnabled,
                      onChanged: _toggleVoiceNotifications,
                      secondary: const Icon(Icons.record_voice_over),
                      tileColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Account Actions
                    Text(
                      'Account Actions',
                      style: AppTheme.headingMedium.copyWith(
                        color: isDark
                            ? const Color(0xFFF5F5DC)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningColor,
                        side: const BorderSide(color: AppTheme.warningColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
