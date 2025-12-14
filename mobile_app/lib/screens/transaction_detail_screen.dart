import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../models/models.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String merchantId;
  final String userId;
  final String name;
  final double balance;

  const TransactionDetailScreen({
    super.key,
    required this.merchantId,
    required this.userId,
    required this.name,
    required this.balance,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
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

  Future<void> _showAddBalanceDialog() async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Balance'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                await _showPinDialog(amount);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinDialog(double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Add Balance'),
        content:
            Text('Add ₹${amount.toStringAsFixed(2)} to this user\'s balance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Add Balance'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _addBalance(amount, '');
    }
  }

  Future<void> _addBalance(double amount, String pin) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      await walletProvider.addBalance(
        merchantId: widget.merchantId,
        userId: widget.userId,
        amount: amount,
        pin: '', // No PIN required for merchant
        token: authProvider.token!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Balance added successfully!'),
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
        title: Text(widget.name),
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
        onPressed: _showAddBalanceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Balance'),
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
          const Text('Current Balance',
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
