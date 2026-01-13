import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import '../utils/auth_error_handler.dart';
import '../models/models.dart';
import '../services/websocket_service.dart';
import 'home_screen.dart';
import 'link_merchant_screen.dart';
import 'request_balance_screen.dart';
import 'pay_merchant_screen.dart';
import 'accept_pay_request_screen.dart';
import 'user_settings_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AuthErrorHandler {
  final TextEditingController _searchController = TextEditingController();
  List<MerchantUserLink> _filteredLinks = [];
  List<Transaction> _allTransactions = [];
  List<PayRequest> _payRequests = [];
  List<UserNotification> _notifications = [];
  bool _isLoadingTransactions = false;
  bool _isLoadingPayRequests = false;
  bool _isLoadingNotifications = false;
  late TabController _tabController;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  // Caching variables - increased for better performance
  DateTime? _lastTransactionLoad;
  DateTime? _lastPayRequestLoad;
  DateTime? _lastNotificationLoad;
  DateTime? _lastMerchantLoad;
  static const _cacheDuration = Duration(minutes: 5);

  // Debounce timer for search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Lazy load data when switching tabs
      if (_tabController.index == 1) {
        _loadTransactionsIfNeeded();
      } else if (_tabController.index == 2) {
        _loadNotificationsIfNeeded();
        _loadPayRequestsIfNeeded();
      }
    });
    _searchController.addListener(_debouncedFilterLinks);
    _setupWebSocketListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load data asynchronously without blocking UI
      _loadData().catchError((e) => print('Error loading merchants: $e'));
      _loadTransactions()
          .catchError((e) => print('Error loading transactions: $e'));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _invalidateCaches(); // Invalidate caches on resume
      _loadTransactions().then((_) => _loadData());
      if (_tabController.index == 2) {
        _loadPayRequestsIfNeeded();
      }
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Setup WebSocket listener for real-time updates
  void _setupWebSocketListener() {
    final ws = WebSocketService();
    _wsSubscription = ws.messages?.listen((message) {
      final event = message['event'];
      print('User Dashboard: Received WebSocket event - $event');

      switch (event) {
        case 'payment_requested':
          // Reload pay requests when new request arrives
          _loadPayRequests();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New payment request received!'),
                backgroundColor: AppTheme.primaryColor,
                duration: Duration(seconds: 3),
              ),
            );
          }
          break;
        case 'balance_updated':
          // Reload data when balance is updated
          _invalidateCaches();
          _loadData();
          break;
        case 'reminder_created':
          // Reload notifications when new reminder is created
          print('User Dashboard: New reminder received');
          _loadNotifications();

          final data = message['data'];
          final storeName = data['store_name'] ?? 'Store';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New payment reminder from $storeName'),
                backgroundColor: AppTheme.warningColor,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    _tabController.animateTo(2); // Switch to notifications tab
                  },
                ),
              ),
            );
          }
          break;
        case 'reminder_dismissed':
          // Remove dismissed reminder from list
          print('User Dashboard: Reminder dismissed');
          final data = message['data'];
          if (mounted && data != null) {
            setState(() {
              _notifications.removeWhere((n) => n.id == data['reminder_id']);
            });
          }
          break;
      }
    });
  }

  // Debounced search for better performance
  void _debouncedFilterLinks() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _filterLinks();
    });
  }

  void _filterLinks() {
    _applySorting();
  }

  List<MerchantUserLink> _sortMerchantsByRecentTransaction(
      List<MerchantUserLink> links) {
    // Create a map of merchant ID to most recent transaction time
    final Map<String, DateTime> lastTransactionTime = {};

    for (var transaction in _allTransactions) {
      final merchantId = transaction.merchantId;
      final transactionTime = transaction.createdAt;

      if (transactionTime != null) {
        if (!lastTransactionTime.containsKey(merchantId) ||
            transactionTime.isAfter(lastTransactionTime[merchantId]!)) {
          lastTransactionTime[merchantId] = transactionTime;
        }
      }
    }

    // Sort links by most recent transaction time
    links.sort((a, b) {
      final aTime = lastTransactionTime[a.merchantId];
      final bTime = lastTransactionTime[b.merchantId];

      // If both have transactions, sort by time (most recent first)
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      // If only a has transactions, a comes first
      if (aTime != null) return -1;
      // If only b has transactions, b comes first
      if (bTime != null) return 1;
      // If neither has transactions, keep original order
      return 0;
    });

    return links;
  }

  // Cache helper methods
  bool _isCacheValid(DateTime? lastLoad) {
    if (lastLoad == null) return false;
    return DateTime.now().difference(lastLoad) < _cacheDuration;
  }

  void _invalidateCaches() {
    _lastTransactionLoad = null;
    _lastPayRequestLoad = null;
    _lastNotificationLoad = null;
    _lastMerchantLoad = null;
  }

  Future<void> _loadData() async {
    print('USER DASHBOARD: Starting _loadData');
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId != null && authProvider.token != null) {
      // Check cache validity
      if (_isCacheValid(_lastMerchantLoad) && walletProvider.links.isNotEmpty) {
        print(
            'USER DASHBOARD: Using cached merchant data (${walletProvider.links.length} links)');
        return; // Use cached data
      }

      print('USER DASHBOARD: Fetching merchant links...');
      await handleAuthErrors(() async {
        await walletProvider.fetchLinkedMerchants(
          authProvider.userId!,
          authProvider.token!,
        );
        print(
            'USER DASHBOARD: Fetched ${walletProvider.links.length} merchant links');
        _lastMerchantLoad = DateTime.now();
        // Show merchants immediately without sorting
        if (mounted) {
          setState(() {
            _filteredLinks = List.from(walletProvider.links);
            print(
                'USER DASHBOARD: Displayed ${_filteredLinks.length} links (sorting deferred)');
          });
          // Sort in next frame if transactions are available
          if (_allTransactions.isNotEmpty) {
            _applySorting();
          }
        }
      });
    } else {
      print('USER DASHBOARD: No auth credentials for loading data');
    }
  }

  // Apply sorting without blocking - called after transactions load
  void _applySorting() {
    if (!mounted) return;
    final walletProvider = context.read<WalletProvider>();
    final query = _searchController.text.toLowerCase();

    List<MerchantUserLink> links;
    if (query.isEmpty) {
      links = List.from(walletProvider.links);
    } else {
      links = walletProvider.links.where((link) {
        final storeName = link.storeName?.toLowerCase() ?? '';
        final merchantId = link.merchantId.toLowerCase();
        return storeName.contains(query) || merchantId.contains(query);
      }).toList();
    }

    setState(() {
      _filteredLinks = _sortMerchantsByRecentTransaction(links);
    });
  }

  // Smart loading methods
  Future<void> _loadTransactionsIfNeeded() async {
    if (_isCacheValid(_lastTransactionLoad) && _allTransactions.isNotEmpty) {
      return; // Use cached data
    }
    await _loadTransactions();
  }

  Future<void> _loadPayRequestsIfNeeded() async {
    if (_isCacheValid(_lastPayRequestLoad) && _payRequests.isNotEmpty) {
      return; // Use cached data
    }
    await _loadPayRequests();
  }

  Future<void> _loadTransactions() async {
    print('USER DASHBOARD: Starting _loadTransactions');
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId == null || authProvider.token == null) {
      print('USER DASHBOARD: No auth credentials for transactions');
      return;
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingTransactions) {
      print('USER DASHBOARD: Already loading transactions, skipping');
      return;
    }

    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      print('USER DASHBOARD: Fetching transactions...');
      await handleAuthErrors(() async {
        final transactions =
            await walletProvider.apiService.getUserTransactions(
          userId: authProvider.userId!,
          token: authProvider.token!,
        );

        print('USER DASHBOARD: Fetched ${transactions.length} transactions');

        if (mounted) {
          setState(() {
            _allTransactions = transactions;
            _lastTransactionLoad = DateTime.now();
            // Apply sorting now that transactions are available
            if (_filteredLinks.isNotEmpty) {
              _applySorting();
            }
          });
        }
      });
    } catch (e) {
      print('USER DASHBOARD: Error loading transactions: $e');
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
      }
      print('USER DASHBOARD: Finished _loadTransactions');
    }
  }

  Future<void> _loadPayRequests() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId == null || authProvider.token == null) return;

    // Prevent multiple simultaneous loads
    if (_isLoadingPayRequests) return;

    setState(() {
      _isLoadingPayRequests = true;
    });

    await handleAuthErrors(() async {
      final payRequests = await walletProvider.apiService.getUserPayRequests(
        authProvider.userId!,
        authProvider.token!,
      );

      if (mounted) {
        setState(() {
          _payRequests = payRequests;
          _lastPayRequestLoad = DateTime.now();
          _isLoadingPayRequests = false;
        });
      }
    });

    // Reset loading state in case of error
    if (mounted) {
      setState(() {
        _isLoadingPayRequests = false;
      });
    }
  }

  Future<void> _loadNotificationsIfNeeded() async {
    if (_lastNotificationLoad != null &&
        DateTime.now().difference(_lastNotificationLoad!) < _cacheDuration) {
      return;
    }
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.userId == null || authProvider.token == null) {
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
        });
      }
      return;
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingNotifications) return;

    setState(() {
      _isLoadingNotifications = true;
    });

    try {
      await handleAuthErrors(() async {
        final notifications =
            await walletProvider.apiService.getUserNotifications(
          token: authProvider.token!,
          userId: authProvider.userId!,
        );

        if (mounted) {
          setState(() {
            _notifications = notifications;
            _lastNotificationLoad = DateTime.now();
            _isLoadingNotifications = false;
          });
        }
      });
    } catch (e) {
      print('Error loading notifications: $e');
      // Reset loading state in case of error
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
        });
      }
    }
  }

  Future<void> _handleAcceptPayRequest(PayRequest request) async {
    // Find the user's balance for this merchant
    final walletProvider = context.read<WalletProvider>();
    final link = walletProvider.links.firstWhere(
      (l) => l.merchantId == request.merchantId,
      orElse: () => MerchantUserLink(
        linkId: request.id,
        merchantId: request.merchantId,
        userId: request.userId,
        balance: 0.0,
      ),
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcceptPayRequestScreen(
          payRequest: request,
          currentBalance: link.balance,
        ),
      ),
    );

    if (result == true) {
      // Invalidate caches and reload data after successful payment
      _lastTransactionLoad = null;
      _lastPayRequestLoad = null;
      _lastMerchantLoad = null;
      await _loadData();
      await _loadPayRequests();
      await _loadTransactions();
    }
  }

  Future<void> _handleRejectPayRequest(PayRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment Request'),
        content: Text(
          'Are you sure you want to reject the payment request of ₹${request.amount.toStringAsFixed(2)} from ${request.storeName ?? request.merchantId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.token == null) return;

    try {
      await walletProvider.apiService.rejectPayRequest(
        request.id,
        authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment request rejected'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        _lastPayRequestLoad = null;
        await _loadPayRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
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

    print(
        'USER DASHBOARD BUILD: walletProvider.isLoading=${walletProvider.isLoading}, links=${walletProvider.links.length}, _isLoadingTransactions=$_isLoadingTransactions, _isLoadingNotifications=$_isLoadingNotifications');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserSettingsScreen(),
                ),
              );
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
    );
  }

  Widget _buildMerchantsTab(
      AuthProvider authProvider, WalletProvider walletProvider) {
    return RefreshIndicator(
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
            _buildHeaderCard(authProvider),
            const SizedBox(height: 12),
            _buildStatsCard(walletProvider.links),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildLinkedMerchantsSection(walletProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        _lastTransactionLoad = null; // Invalidate cache
        await _loadTransactions();
      },
      child: _isLoadingTransactions && _allTransactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _allTransactions.isEmpty
              ? ListView(
                  // Wrap in ListView for RefreshIndicator
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
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
                      ),
                    ),
                  ],
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

    if (_isLoadingNotifications && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadNotifications();
      },
      child: _notifications.isNotEmpty
          ? ListView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildReminderNotificationCard(notification, isDark);
              },
            )
          : Center(
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
                    const SizedBox(height: 8),
                    Text(
                      'Payment reminders will appear here',
                      style: TextStyle(
                        color:
                            isDark ? const Color(0xFFE5E5CC) : Colors.grey[500],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReminderNotificationCard(
      UserNotification notification, bool isDark) {
    final isPastDue = notification.reminderDate.isBefore(DateTime.now());
    final dateStr = _formatNotificationDate(notification.reminderDate);

    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _dismissNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        color: isDark ? const Color(0xFF252838) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isPastDue
                ? AppTheme.errorColor.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isPastDue
                        ? AppTheme.errorColor.withValues(alpha: 0.2)
                        : AppTheme.primaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      isPastDue
                          ? Icons.notification_important
                          : Icons.notifications_active,
                      color: isPastDue
                          ? AppTheme.errorColor
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.storeName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? const Color(0xFFF5F5DC) : Colors.black,
                          ),
                        ),
                        Text(
                          'Balance: ₹${notification.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: notification.balance < 0
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPastDue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFFE5E5CC) : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isPastDue ? AppTheme.errorColor : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPastDue
                          ? AppTheme.errorColor
                          : (isDark
                              ? const Color(0xFFE5E5CC)
                              : Colors.grey[600]),
                      fontWeight:
                          isPastDue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _dismissNotification(notification.id),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child:
                        const Text('Dismiss', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNotificationDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDate = DateTime(date.year, date.month, date.day);

    if (notifDate == today) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (notifDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (notifDate.isAfter(today) &&
        notifDate.isBefore(today.add(const Duration(days: 7)))) {
      final weekday =
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
      return '$weekday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _dismissNotification(int reminderId) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final walletProvider = context.read<WalletProvider>();
      final token = authProvider.token;

      if (token == null) {
        throw Exception('Not authenticated');
      }

      await walletProvider.apiService.dismissNotification(
        token: token,
        reminderId: reminderId,
      );

      // Remove from local list
      setState(() {
        _notifications.removeWhere((n) => n.id == reminderId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification dismissed'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateNotifications(
      List<MerchantUserLink> merchantLinks) {
    List<Map<String, dynamic>> notifications = [];

    // Generate notifications for each merchant link
    for (var link in merchantLinks) {
      final balance = link.balance;
      final storeName = link.storeName;
      final createdAt = link.createdAt;

      // Merchant linked notification
      notifications.add({
        'type': 'link_success',
        'title': 'Successfully Linked',
        'message': 'You are now linked with $storeName',
        'timestamp': createdAt,
        'icon': Icons.link,
        'color': Colors.green,
      });

      // Low balance alert (balance below 100)
      if (balance < 100 && balance >= 0) {
        notifications.add({
          'type': 'low_balance',
          'title': 'Low Balance Alert',
          'message':
              'Your balance with $storeName is ₹${balance.toStringAsFixed(2)}',
          'timestamp': DateTime.now(),
          'icon': Icons.warning_amber_rounded,
          'color': Colors.orange,
        });
      }

      // Negative balance alert
      if (balance < 0) {
        notifications.add({
          'type': 'negative_balance',
          'title': 'Negative Balance',
          'message':
              'You owe ₹${balance.abs().toStringAsFixed(2)} to $storeName. Please pay back soon.',
          'timestamp': DateTime.now(),
          'icon': Icons.error_outline,
          'color': Colors.red,
          'actionable': true,
          'merchantId': link.merchantId,
          'userId': link.userId,
        });
      }
    }

    // Sort by timestamp (newest first)
    notifications.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return notifications;
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, bool isDark) {
    final title = notification['title'] as String;
    final message = notification['message'] as String;
    final timestamp = notification['timestamp'] as DateTime?;
    final icon = notification['icon'] as IconData;
    final color = notification['color'] as Color;
    final isActionable = notification['actionable'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? const Color(0xFF252838) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[700],
                fontSize: 13,
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE5E5CC).withValues(alpha: 0.6)
                      : Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        trailing: isActionable
            ? IconButton(
                icon: const Icon(Icons.payment, color: AppTheme.primaryColor),
                onPressed: () {
                  // Navigate to payment screen
                  _showPaymentDialog(
                    notification['merchantId'] as String,
                    notification['userId'] as String,
                  );
                },
              )
            : null,
      ),
    );
  }

  void _showPaymentDialog(String merchantId, String userId) {
    final walletProvider = context.read<WalletProvider>();
    final link = walletProvider.links.firstWhere(
      (l) => l.merchantId == merchantId && l.userId == userId,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay Back Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant: ${link.storeName}'),
            const SizedBox(height: 8),
            Text(
              'Amount Due: ₹${link.balance.abs().toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Please visit the merchant to settle your balance.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayRequestCard(PayRequest request,
      {required bool isPending, required bool isDark}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 4 : 2,
      color: isDark ? const Color(0xFF252838) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.2),
                  radius: 18,
                  child: const Icon(Icons.payment,
                      color: AppTheme.errorColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.storeName ?? request.merchantId,
                        style: TextStyle(
                          color:
                              isDark ? const Color(0xFFF5F5DC) : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.createdAt != null
                            ? '${request.createdAt!.day}/${request.createdAt!.month}/${request.createdAt!.year} ${request.createdAt!.hour}:${request.createdAt!.minute.toString().padLeft(2, '0')}'
                            : 'Unknown date',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFE5E5CC)
                              : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${request.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (request.description != null &&
                request.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.description!,
                style: TextStyle(
                  color: isDark ? const Color(0xFFE5E5CC) : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAcceptPayRequest(request),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleRejectPayRequest(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    request.status == 'accepted'
                        ? Icons.check_circle
                        : Icons.cancel,
                    size: 16,
                    color: request.status == 'accepted'
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    request.status == 'accepted' ? 'Accepted' : 'Rejected',
                    style: TextStyle(
                      color: request.status == 'accepted'
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (request.respondedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${request.respondedAt!.day}/${request.respondedAt!.month}/${request.respondedAt!.year}',
                      style: TextStyle(
                        color:
                            isDark ? const Color(0xFFE5E5CC) : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hello,',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            authProvider.userName ?? 'User',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('ID: ${authProvider.userId}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
              child: _buildStatItem(
                  'Merchants', links.length.toString(), Icons.store)),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(child: _buildLinkMerchantButton()),
        ],
      ),
    );
  }

  Widget _buildLinkMerchantButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LinkMerchantScreen(),
          ),
        );
        if (result == true) {
          await _loadData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, color: AppTheme.primaryColor, size: 28),
            const SizedBox(height: 4),
            Text(
              'Link',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
              ),
            ),
            Text(
              'Merchant',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
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
      ),
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
          style: AppTheme.headingSmall.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF5F5DC)
                : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
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
          Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredLinks.length,
                itemBuilder: (context, index) =>
                    _buildMerchantCard(_filteredLinks[index]),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _invalidateCaches();
                    _loadData();
                  },
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

  Widget _buildMerchantCard(MerchantUserLink link) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      color: isDark ? const Color(0xFF252838) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    link.storeName?.substring(0, 1).toUpperCase() ?? 'M',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.storeName ?? 'Unknown Store',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? const Color(0xFFF5F5DC) : Colors.black,
                        ),
                      ),
                      Text(
                        'ID: ${link.merchantId}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFFE5E5CC) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${link.balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: link.balance < 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestBalanceScreen(link: link),
                        ),
                      );
                      if (result == true) await _loadData();
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Request Balance',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PayMerchantScreen(link: link),
                        ),
                      );
                      if (result == true) {
                        _invalidateCaches();
                        // Load transactions first for proper sorting
                        await _loadTransactions();
                        await _loadData();
                      }
                    },
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text(
                      'Pay Merchant',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 48),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter PIN to delink from ${link.storeName}'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],
          ),
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
        _lastMerchantLoad = null;
        _lastTransactionLoad = null;
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
        content: SingleChildScrollView(
          child: Column(
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
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.done,
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
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balance request sent successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Invalidate caches and reload
        _lastMerchantLoad = null;
        _lastTransactionLoad = null;
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
          'Pay to Merchant',
          style: TextStyle(
            color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
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
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.done,
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
                // Allow negative balance - no balance check
                Navigator.pop(context);
                _performPurchase(link, amount, pinController.text);
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
            child: const Text('Confirm Payment'),
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
        // Invalidate caches and reload
        _lastMerchantLoad = null;
        _lastTransactionLoad = null;
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
        content: SingleChildScrollView(
          child: Column(
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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 20),
              Text(
                'Set PIN (4 digits):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFF5F5DC) : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Pinput(
                controller: pinController,
                length: 4,
                obscureText: true,
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.white,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF5a5d6a)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3a3d4a) : Colors.white,
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (merchantIdController.text.isNotEmpty &&
                  pinController.text.length == 4) {
                Navigator.pop(context);
                _submitLinkRequest(
                  merchantIdController.text,
                  pinController.text,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Please enter valid merchant ID and 4-digit PIN'),
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
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link request sent successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Invalidate cache and reload
        _lastMerchantLoad = null;
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
          'Are you sure you want to log out? You will need to enter your user ID and password again to login.',
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
