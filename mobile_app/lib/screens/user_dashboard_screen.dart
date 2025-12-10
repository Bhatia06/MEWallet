import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import 'home_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<MerchantUserLink> _filteredLinks = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterLinks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterLinks() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      final walletProvider = context.read<WalletProvider>();
      if (query.isEmpty) {
        _filteredLinks = walletProvider.links;
      } else {
        _filteredLinks = walletProvider.links.where((link) {
          final storeName = link.storeName?.toLowerCase() ?? '';
          final merchantId = link.merchantId.toLowerCase();
          return storeName.contains(query) || merchantId.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      await walletProvider.fetchLinkedMerchants(
        authProvider.userId!,
        authProvider.token!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(authProvider),
              const SizedBox(height: 24),
              _buildStatsCard(walletProvider.links),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildLinkedMerchantsSection(walletProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hello,',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            authProvider.userName ?? 'User',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('ID: ${authProvider.userId}',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by merchant name or ID...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
      ),
    );
  }

  Widget _buildStatsCard(List<MerchantUserLink> links) {
    final totalBalance =
        links.fold<double>(0, (sum, link) => sum + link.balance);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252838) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Merchants', links.length.toString(), Icons.store),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _buildStatItem('Total Balance', '₹${totalBalance.toStringAsFixed(2)}',
              Icons.account_balance_wallet),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedMerchantsSection(WalletProvider walletProvider) {
    if (_filteredLinks.isEmpty && _searchController.text.isEmpty) {
      _filteredLinks = walletProvider.links;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Merchants',
          style: AppTheme.headingMedium.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF5F5DC)
                : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (walletProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredLinks.isEmpty && _searchController.text.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No merchants found matching "${_searchController.text}"',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFE5E5CC)
                          : Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (walletProvider.links.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredLinks.length,
            itemBuilder: (context, index) =>
                _buildMerchantCard(_filteredLinks[index]),
          ),
      ],
    );
  }

  Widget _buildMerchantCard(MerchantUserLink link) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF252838) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    link.storeName?.substring(0, 1).toUpperCase() ?? 'M',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.storeName ?? 'Unknown Store',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? const Color(0xFFF5F5DC) : Colors.black,
                        ),
                      ),
                      Text(
                        'ID: ${link.merchantId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${link.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showBalanceRequestDialog(link),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Request Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPurchaseDialog(link),
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('Purchase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDelinkDialog(link),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Delink Merchant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDelinkDialog(MerchantUserLink link) async {
    final pinController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delink Merchant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter PIN to delink from ${link.storeName}'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelink(link, pinController.text);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelink(MerchantUserLink link, String pin) async {
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter PIN')),
      );
      return;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delink'),
        content: Text(
          'Are you sure you want to delink from ${link.storeName}?\n\nYour transaction history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelink(link, pin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Yes, Delink'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelink(MerchantUserLink link, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.delinkMerchant(
        merchantId: link.merchantId,
        userId: link.userId,
        pin: pin,
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully delinked!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
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
    }
  }

  Future<void> _showBalanceRequestDialog(MerchantUserLink link) async {
    final amountController = TextEditingController();
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Request Balance',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Request balance from ${link.storeName}',
              style: TextStyle(
                color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'PIN',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.grey,
                  ),
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null &&
                  amount > 0 &&
                  pinController.text.isNotEmpty) {
                Navigator.pop(context);
                _submitBalanceRequest(link, amount, pinController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter valid amount and PIN')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBalanceRequest(
      MerchantUserLink link, double amount, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService.createBalanceRequest(
        merchantId: link.merchantId,
        userId: authProvider.userId!,
        amount: amount,
        pin: pin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balance request sent successfully!'),
            backgroundColor: AppTheme.successColor,
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
    }
  }

  Future<void> _showPurchaseDialog(MerchantUserLink link) async {
    final amountController = TextEditingController();
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Make Purchase',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Balance: ₹${link.balance.toStringAsFixed(2)}',
              style: TextStyle(
                color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'PIN',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                ),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.grey,
                  ),
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null &&
                  amount > 0 &&
                  pinController.text.isNotEmpty) {
                if (amount > link.balance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insufficient balance')),
                  );
                } else {
                  Navigator.pop(context);
                  _performPurchase(link, amount, pinController.text);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter valid amount and PIN')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }

  Future<void> _performPurchase(
      MerchantUserLink link, double amount, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.processPurchase(
        merchantId: link.merchantId,
        userId: authProvider.userId!,
        amount: amount,
        pin: pin,
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
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
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No linked merchants yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Tap the + button to link with a merchant',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
