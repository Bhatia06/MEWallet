import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import '../utils/auth_error_handler.dart';
import '../models/models.dart';
import '../services/tts_service.dart';
import 'home_screen.dart';
import 'add_user_screen.dart';
import 'transaction_detail_screen.dart';
import 'merchant_deduct_balance_screen.dart';
import 'merchant_settings_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AuthErrorHandler {
  final TextEditingController _searchController = TextEditingController();
  List<MerchantUserLink> _filteredLinks = [];
  List<BalanceRequest> _balanceRequests = [];
  List<LinkRequest> _linkRequests = [];
  List<Transaction> _allTransactions = [];
  late TabController _tabController;

  // Caching variables
  DateTime? _lastTransactionLoad;
  DateTime? _lastRequestLoad;
  DateTime? _lastUserLoad;
  static const _cacheDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadBalanceRequestsIfNeeded();
      } else if (_tabController.index == 2) {
        _loadAllTransactionsIfNeeded();
      }
    });
    _searchController.addListener(_filterLinks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _invalidateCaches();
      _loadData();
      if (_tabController.index == 1) {
        _loadBalanceRequestsIfNeeded();
      } else if (_tabController.index == 2) {
        _loadAllTransactionsIfNeeded();
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
          final userName = link.userName?.toLowerCase() ?? '';
          final userId = link.userId.toLowerCase();
          return userName.contains(query) || userId.contains(query);
        }).toList();
      }
    });
  }

  // Cache helper methods
  bool _isCacheValid(DateTime? lastLoad) {
    if (lastLoad == null) return false;
    return DateTime.now().difference(lastLoad) < _cacheDuration;
  }

  void _invalidateCaches() {
    _lastTransactionLoad = null;
    _lastRequestLoad = null;
    _lastUserLoad = null;
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      // Check cache validity
      if (_isCacheValid(_lastUserLoad) && walletProvider.links.isNotEmpty) {
        return; // Use cached data
      }

      await handleAuthErrors(() async {
        await walletProvider.fetchLinkedUsers(
          authProvider.userId!,
          authProvider.token!,
        );
        _lastUserLoad = DateTime.now();
        await _loadBalanceRequestsIfNeeded();
        // Force UI update
        if (mounted) {
          setState(() {
            _filteredLinks = walletProvider.links;
          });
        }
      });
    }
  }

  // Smart loading methods
  Future<void> _loadBalanceRequestsIfNeeded() async {
    if (_isCacheValid(_lastRequestLoad) &&
        (_balanceRequests.isNotEmpty || _linkRequests.isNotEmpty)) {
      return; // Use cached data
    }
    await _loadBalanceRequests();
  }

  Future<void> _loadAllTransactionsIfNeeded() async {
    if (_isCacheValid(_lastTransactionLoad) && _allTransactions.isNotEmpty) {
      return; // Use cached data
    }
    await _loadAllTransactions();
  }

  Future<void> _loadBalanceRequests() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      await handleAuthErrors(() async {
        final balanceReqs = await walletProvider.apiService
            .getMerchantRequests(authProvider.userId!, authProvider.token!);
        final linkReqs = await walletProvider.apiService
            .getMerchantLinkRequests(authProvider.userId!, authProvider.token!);
        if (mounted) {
          setState(() {
            _balanceRequests = balanceReqs;
            _linkRequests = linkReqs;
            _lastRequestLoad = DateTime.now();
          });
        }
      });
    }
  }

  Future<void> _loadAllTransactions() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      await handleAuthErrors(() async {
        final transactions =
            await walletProvider.apiService.getMerchantTransactions(
          merchantId: authProvider.userId!,
          token: authProvider.token!,
        );
        if (mounted) {
          setState(() {
            _allTransactions = transactions;
            _lastTransactionLoad = DateTime.now();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
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
                child: const Text('Exit'),
              ),
            ],
          ),
        );

        if (shouldExit == true && context.mounted) {
          // Exit the app
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MerchantSettingsScreen(),
                  ),
                );
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
                Tab(text: 'Transactions', icon: Icon(Icons.receipt_long)),
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
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsCard(walletProvider.links),
                          const SizedBox(height: 12),
                          _buildSearchBar(),
                          const SizedBox(height: 10),
                          _buildLinkedUsersSection(walletProvider),
                        ],
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      _lastRequestLoad = null;
                      await _loadBalanceRequests();
                    },
                    child: _buildRequestsTab(),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      _lastTransactionLoad = null;
                      await _loadAllTransactions();
                    },
                    child: _buildTransactionsTab(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome,',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  authProvider.userName ?? 'Merchant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${authProvider.userId}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddUserScreen()),
                  );
                  if (result == true) _loadData();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Add User',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252838) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
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
          Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredLinks.length,
                itemBuilder: (context, index) {
                  final link = _filteredLinks[index];
                  return _buildUserCard(link);
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildUserCard(MerchantUserLink link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserActionsBottomSheet(link),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  link.userName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.userName ?? 'Unknown User',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF5F5DC)
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${link.userId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE5E5CC)
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${link.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: link.balance < 0
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                    if (link.balance < 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Owes you ₹${(-link.balance).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalRequests = _balanceRequests.length + _linkRequests.length;

    if (totalRequests == 0) {
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
                  'Link and balance requests from users will appear here',
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

    return ListView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      children: [
        ..._linkRequests.map((request) => _buildLinkRequestCard(request)),
        ..._balanceRequests.map((request) => _buildBalanceRequestCard(request)),
      ],
    );
  }

  Widget _buildLinkRequestCard(LinkRequest request) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Link request',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                Icon(
                  Icons.link,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptLinkRequest(request),
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
                    onPressed: () => _rejectLinkRequest(request),
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

  Widget _buildBalanceRequestCard(BalanceRequest request) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Balance request',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
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
      await walletProvider.apiService
          .acceptBalanceRequest(request.id!, authProvider.token!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request.userName} accepted!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _lastRequestLoad = null;
        _lastUserLoad = null;
        _lastTransactionLoad = null;
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
      await walletProvider.apiService
          .rejectBalanceRequest(request.id!, authProvider.token!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request.userName} rejected'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        _lastRequestLoad = null;
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

  Future<void> _acceptLinkRequest(LinkRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService
          .acceptLinkRequest(request.id!, authProvider.token!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link request from ${request.userName} accepted!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _lastRequestLoad = null;
        _lastUserLoad = null;
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

  Future<void> _rejectLinkRequest(LinkRequest request) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.apiService
          .rejectLinkRequest(request.id!, authProvider.token!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link request from ${request.userName} rejected'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        _lastRequestLoad = null;
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

  Widget _buildTransactionsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        _lastTransactionLoad = null;
        await _loadAllTransactions();
      },
      child: _allTransactions.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? const Color(0xFFE5E5CC)
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? const Color(0xFFE5E5CC)
                                : Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              itemCount: _allTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _allTransactions[index];
                return _buildTransactionCard(transaction, isDark);
              },
            ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, bool isDark) {
    final isCredit = transaction.transactionType == 'add_balance' ||
        transaction.transactionType == 'credit';
    final amount = transaction.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF252838) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isCredit ? AppTheme.successColor : AppTheme.errorColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? AppTheme.successColor : AppTheme.errorColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.userName ?? 'Unknown User',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCredit ? 'Balance Added' : 'Purchase',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? const Color(0xFFE5E5CC) : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCredit ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    try {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  void _showUserActionsBottomSheet(MerchantUserLink link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252838)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                link.userName ?? 'User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF5F5DC)
                      : Colors.black,
                ),
              ),
              Text(
                'Balance: ₹${link.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE5E5CC)
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MerchantDeductBalanceScreen(link: link),
                    ),
                  );
                  if (result == true) {
                    _lastUserLoad = null;
                    _lastTransactionLoad = null;
                    await _loadData();
                    await _loadAllTransactions();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    const Text('Request Pay', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddBalanceDialog(link);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    const Text('Add Balance', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
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
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    const Text('Transactions', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showAddBalanceDialog(MerchantUserLink link) {
    final amountController = TextEditingController();

    // Capture context references before showing dialogs
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
          title: Text(
            'Add Balance',
            style: TextStyle(
              color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add balance for ${link.userName}',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return AlertDialog(
                      backgroundColor:
                          isDark ? const Color(0xFF252838) : Colors.white,
                      title: Text(
                        'Confirm Add Balance',
                        style: TextStyle(
                          color:
                              isDark ? const Color(0xFFF5F5DC) : Colors.black,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You are going to add ₹${amount.toStringAsFixed(2)} to ${link.userName}.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFE5E5CC)
                                  : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Please confirm the amount and the name before proceeding.',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmContext, false),
                          child: const Text('Go back'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(confirmContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed != true) return;

                try {
                  await walletProvider.apiService.addBalance(
                    merchantId: link.merchantId,
                    userId: link.userId,
                    amount: amount,
                    token: authProvider.token!,
                  );

                  _lastUserLoad = null;
                  _lastTransactionLoad = null;
                  await _loadData();
                  await _loadAllTransactions();

                  if (mounted) {
                    // Play voice notification
                    TtsService().announceBalanceAdded(
                      amount: amount,
                      merchantName: authProvider.userName ?? 'Merchant',
                      userType: 'user',
                    );

                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            '₹${amount.toStringAsFixed(2)} added successfully to ${link.userName}!'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
              ),
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogoutConfirmation(AuthProvider authProvider) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF252838) : Colors.white,
        title: Text(
          'Logout Confirmation',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to log out? You will need to enter your merchant ID and password again to login.',
          style: TextStyle(
            color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
          ),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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
