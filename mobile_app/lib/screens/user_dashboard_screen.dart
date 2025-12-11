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

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<MerchantUserLink> _filteredLinks = [];
  List<Transaction> _allTransactions = [];
  bool _isLoadingTransactions = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadTransactions();
      } else if (_tabController.index == 2) {
        _loadTransactions(); // Load for notifications too
      }
    });
    _searchController.addListener(_filterLinks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadTransactions(); // Load transactions on start
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _loadData();
      if (_tabController.index == 1 || _tabController.index == 2) {
        _loadTransactions();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
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
      // Force UI update
      if (mounted) {
        setState(() {
          _filteredLinks = walletProvider.links;
        });
      }
    }
  }

  Future<void> _loadTransactions() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId == null || authProvider.token == null) return;

    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      final transactions = await walletProvider.apiService.getUserTransactions(
        userId: authProvider.userId!,
        token: authProvider.token!,
      );

      setState(() {
        _allTransactions = transactions;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadData();
              } else if (_tabController.index == 1) {
                _loadTransactions();
              }
            },
          ),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Merchants'),
            Tab(icon: Icon(Icons.history), text: 'Transactions'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMerchantsTab(authProvider, walletProvider),
          _buildTransactionsTab(),
          _buildNotificationsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showLinkMerchantDialog,
              icon: const Icon(Icons.link),
              label: const Text('Link Merchant'),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
    );
  }

  Widget _buildMerchantsTab(
      AuthProvider authProvider, WalletProvider walletProvider) {
    return RefreshIndicator(
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
    );
  }

  Widget _buildTransactionsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: _isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : _allTransactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFE5E5CC)
                                : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allTransactions.length,
                  itemBuilder: (context, index) {
                    final txn = _allTransactions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: isDark ? const Color(0xFF252838) : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: txn.isCredit
                              ? AppTheme.successColor.withValues(alpha: 0.2)
                              : AppTheme.errorColor.withValues(alpha: 0.2),
                          child: Icon(
                            txn.isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: txn.isCredit
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                        title: Text(
                          txn.storeName ?? txn.merchantId,
                          style: TextStyle(
                            color:
                                isDark ? const Color(0xFFF5F5DC) : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          txn.createdAt != null
                              ? '${txn.createdAt!.day}/${txn.createdAt!.month}/${txn.createdAt!.year} ${txn.createdAt!.hour}:${txn.createdAt!.minute.toString().padLeft(2, '0')}'
                              : 'Unknown date',
                          style: TextStyle(
                            color:
                                isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${txn.isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: txn.isCredit
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              txn.isCredit ? 'Added' : 'Spent',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE5E5CC)
                                    : Colors.grey,
                                fontSize: 12,
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

  Widget _buildNotificationsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentTransactions = _allTransactions.take(10).toList();

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: recentTransactions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: TextStyle(
                        color:
                            isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recentTransactions.length,
              itemBuilder: (context, index) {
                final txn = recentTransactions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  color: isDark ? const Color(0xFF252838) : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: txn.isCredit
                          ? AppTheme.successColor.withValues(alpha: 0.2)
                          : AppTheme.errorColor.withValues(alpha: 0.2),
                      child: Icon(
                        txn.isCredit ? Icons.add : Icons.remove,
                        color: txn.isCredit
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                    title: Text(
                      txn.isCredit ? 'Balance Added' : 'Purchase Made',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'At ${txn.storeName ?? txn.merchantId}',
                          style: TextStyle(
                            color:
                                isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                          ),
                        ),
                        Text(
                          txn.createdAt != null
                              ? '${txn.createdAt!.day}/${txn.createdAt!.month}/${txn.createdAt!.year} ${txn.createdAt!.hour}:${txn.createdAt!.minute.toString().padLeft(2, '0')}'
                              : 'Unknown date',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFE5E5CC).withValues(alpha: 0.7)
                                : Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${txn.isCredit ? '+' : '-'}₹${txn.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: txn.isCredit
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
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
        await _loadData();
        await _loadTransactions();
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
        // Auto-refresh to show updated data
        await _loadData();
        await _loadTransactions();
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
        // Reload both merchants and transactions
        await _loadData();
        await _loadTransactions();
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

  Future<void> _showLinkMerchantDialog() async {
    final merchantIdController = TextEditingController();
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Link with Merchant',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter merchant ID and create a PIN for this link',
              style: TextStyle(
                color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: merchantIdController,
              style: TextStyle(
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Merchant ID',
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
                labelText: 'PIN (4-6 digits)',
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
              if (merchantIdController.text.isNotEmpty &&
                  pinController.text.length >= 4) {
                Navigator.pop(context);
                _submitLinkRequest(
                  merchantIdController.text,
                  pinController.text,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please enter valid merchant ID and PIN (4-6 digits)'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLinkRequest(String merchantId, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService.createLinkRequest(
        merchantId: merchantId,
        userId: authProvider.userId!,
        pin: pin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link request sent successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Auto-refresh to show updated data
        await _loadData();
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
