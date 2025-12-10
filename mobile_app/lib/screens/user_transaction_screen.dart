import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../models/models.dart';

class UserTransactionScreen extends StatefulWidget {
  final String merchantId;
  final String userId;
  final String storeName;
  final double balance;

  const UserTransactionScreen({
    super.key,
    required this.merchantId,
    required this.userId,
    required this.storeName,
    required this.balance,
  });

  @override
  State<UserTransactionScreen> createState() => _UserTransactionScreenState();
}

class _UserTransactionScreenState extends State<UserTransactionScreen> {
  double _currentBalance = 0.0;
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.balance;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final apiService = ApiService();

    try {
      _transactions = await apiService.getTransactions(
        merchantId: widget.merchantId,
        userId: widget.userId,
        token: authProvider.token!,
      );

      final balanceData = await apiService.getBalance(
        merchantId: widget.merchantId,
        userId: widget.userId,
        token: authProvider.token!,
      );
      _currentBalance = balanceData['balance']?.toDouble() ?? 0.0;

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPurchaseDialog() async {
    final amountController = TextEditingController();
    final pinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Enter your PIN:'),
            const SizedBox(height: 8),
            Pinput(
              controller: pinController,
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
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final pin = pinController.text;
              if (amount != null && amount > 0 && pin.length == 4) {
                Navigator.pop(context);
                await _makePurchase(amount, pin);
              }
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePurchase(double amount, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.processPurchase(
        merchantId: widget.merchantId,
        userId: widget.userId,
        amount: amount,
        pin: pin,
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Purchase successful!'),
              backgroundColor: AppTheme.successColor),
        );
        _loadTransactions();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadTransactions),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: Column(
          children: [
            _buildBalanceCard(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Transaction History', style: AppTheme.headingMedium),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPurchaseDialog,
        icon: const Icon(Icons.shopping_cart),
        label: const Text('Make Purchase'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Available Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₹${_currentBalance.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: transaction.isCredit
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.errorColor.withOpacity(0.1),
              child: Icon(
                transaction.isCredit
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: transaction.isCredit
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
              ),
            ),
            title: Text(transaction.isCredit ? 'Balance Added' : 'Purchase'),
            subtitle: Text(
              transaction.createdAt != null
                  ? DateFormat('MMM dd, yyyy hh:mm a')
                      .format(transaction.createdAt!)
                  : 'N/A',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.isCredit
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
                Text(
                  'Bal: ₹${transaction.balanceAfter.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No transactions yet',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
