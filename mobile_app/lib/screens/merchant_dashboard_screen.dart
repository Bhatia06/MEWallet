import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import 'home_screen.dart';
import 'add_user_screen.dart';
import 'transaction_detail_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<MerchantUserLink> _filteredLinks = [];
  List<BalanceRequest> _balanceRequests = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterLinks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
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
          final userName = link.userName?.toLowerCase() ?? '';
          final userId = link.userId.toLowerCase();
          return userName.contains(query) || userId.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      await walletProvider.fetchLinkedUsers(
        authProvider.userId!,
        authProvider.token!,
      );
      await _loadBalanceRequests();
    }
  }

  Future<void> _loadBalanceRequests() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      try {
        final requests = await walletProvider.apiService
            .getMerchantRequests(authProvider.userId!);
        setState(() {
          _balanceRequests = requests;
        });
      } catch (e) {
        print('Error loading balance requests: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
      ),
      body: Column(
        children: [
          _buildHeaderCard(authProvider),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF5F5DC)
                : AppTheme.primaryColor,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFE5E5CC)
                    : Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Requests', icon: Icon(Icons.request_page)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsCard(walletProvider.links),
                        const SizedBox(height: 24),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildLinkedUsersSection(walletProvider),
                      ],
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _loadBalanceRequests,
                  child: _buildRequestsTab(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUserScreen()),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
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
          const Text(
            'Welcome,',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            authProvider.userName ?? 'Merchant',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${authProvider.userId}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name or ID...',
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
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Users', links.length.toString(), Icons.people),
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

  Widget _buildLinkedUsersSection(WalletProvider walletProvider) {
    if (_filteredLinks.isEmpty && _searchController.text.isEmpty) {
      _filteredLinks = walletProvider.links;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked Users',
          style: AppTheme.headingSmall.copyWith(
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
                    'No users found matching "${_searchController.text}"',
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
            itemBuilder: (context, index) {
              final link = _filteredLinks[index];
              return _buildUserCard(link);
            },
          ),
      ],
    );
  }

  Widget _buildUserCard(MerchantUserLink link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                link.userName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.userName ?? 'Unknown User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF5F5DC)
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${link.userId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFE5E5CC)
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${link.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              height: 36,
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(
                        merchantId: link.merchantId,
                        userId: link.userId,
                        name: link.userName ?? 'User',
                        balance: link.balance,
                      ),
                    ),
                  );
                  // Reload data when returning from transaction screen
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Add Balance',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_balanceRequests.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Balance requests from users will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _balanceRequests.length,
      itemBuilder: (context, index) {
        final request = _balanceRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(BalanceRequest request) {
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
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    request.userName?.substring(0, 1).toUpperCase() ?? 'U',
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
                        request.userName ?? 'User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? const Color(0xFFF5F5DC) : Colors.black,
                        ),
                      ),
                      Text(
                        request.userId,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${request.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
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
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(BalanceRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService.acceptBalanceRequest(request.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request.userName} accepted!'),
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

  Future<void> _rejectRequest(BalanceRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService.rejectBalanceRequest(request.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request.userName} rejected'),
            backgroundColor: AppTheme.errorColor,
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
            Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No linked users yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add users',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
