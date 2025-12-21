import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/config.dart';
import 'tts_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _shouldReconnect = true;

  String? _userId;
  String? _userType; // 'user' or 'merchant'

  // Stream of incoming messages
  Stream<Map<String, dynamic>>? get messages => _messageController?.stream;

  // Check if connected
  bool get isConnected => _channel != null;

  /// Connect to WebSocket server
  Future<void> connect(String userId, String userType) async {
    if (_isConnecting) {
      print('WebSocket: Already connecting');
      return;
    }

    if (_channel != null) {
      print('WebSocket: Already connected');
      return;
    }

    _isConnecting = true;
    _userId = userId;
    _userType = userType;
    _shouldReconnect = true;

    try {
      print('WebSocket: Connecting as $userType $userId');

      // Convert HTTP URL to WebSocket URL
      var wsUrl = AppConfig.baseUrl;
      if (wsUrl.startsWith('http://')) {
        wsUrl = wsUrl.replaceFirst('http://', 'ws://');
      } else if (wsUrl.startsWith('https://')) {
        wsUrl = wsUrl.replaceFirst('https://', 'wss://');
      }
      // Remove trailing slash if present
      wsUrl = wsUrl.replaceAll(RegExp(r'/$'), '');

      final uri = Uri.parse('$wsUrl/ws/connect/$userType/$userId');
      print('WebSocket: Connecting to $uri');

      _channel = WebSocketChannel.connect(uri);
      _messageController = StreamController<Map<String, dynamic>>.broadcast();

      // Listen to incoming messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            print('WebSocket: Received message - ${data['event']}');
            _messageController?.add(data);

            // Handle specific events
            _handleMessage(data);
          } catch (e) {
            print('WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket: Error - $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket: Connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      // Start ping timer to keep connection alive
      _startPingTimer();

      _isConnecting = false;
      print('WebSocket: Connected successfully');
    } catch (e) {
      print('WebSocket: Connection error - $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(Map<String, dynamic> data) {
    final event = data['event'];
    final eventData = data['data'];

    switch (event) {
      case 'connected':
        print('WebSocket: Connection confirmed');
        break;

      case 'payment_received':
        // Merchant received payment from user
        if (eventData != null) {
          _handlePaymentReceived(eventData);
        }
        break;

      case 'balance_added':
        // Merchant received balance addition from user
        if (eventData != null) {
          _handleBalanceAdded(eventData);
        }
        break;

      case 'payment_requested':
        // User received payment request from merchant
        if (eventData != null) {
          _handlePaymentRequested(eventData);
        }
        break;

      case 'balance_updated':
        // User's balance was updated
        if (eventData != null) {
          _handleBalanceUpdated(eventData);
        }
        break;

      default:
        print('WebSocket: Unknown event - $event');
    }
  }

  /// Handle payment received event (for merchants)
  void _handlePaymentReceived(Map<String, dynamic> data) async {
    final amount = data['amount'];
    print('WebSocket: Payment received - ₹${amount ?? 0}');

    // Play TTS if enabled
    if (_userType == 'merchant' && amount != null) {
      final ttsService = TtsService();
      final amountDouble =
          amount is int ? amount.toDouble() : (amount as num).toDouble();

      await ttsService.announcePaymentReceived(
        amount: amountDouble,
        userName: data['user_name'] ?? 'Customer',
        userType: 'merchant',
      );
    }
  }

  /// Handle balance added event (for merchants)
  void _handleBalanceAdded(Map<String, dynamic> data) async {
    final amount = data['amount'];
    print('WebSocket: Balance added - ₹${amount ?? 0}');

    // Play TTS if enabled
    if (_userType == 'merchant' && amount != null) {
      final ttsService = TtsService();
      final amountDouble =
          amount is int ? amount.toDouble() : (amount as num).toDouble();

      await ttsService.announceBalanceAdded(
        amount: amountDouble,
        merchantName: data['merchant_name'] ?? 'Merchant',
        userType: 'merchant',
      );
    }
  }

  /// Handle payment requested event (for users)
  void _handlePaymentRequested(Map<String, dynamic> data) {
    print('WebSocket: Payment requested - ₹${data['amount'] ?? 0}');
    // UI will handle showing notification
  }

  /// Handle balance updated event (for users)
  void _handleBalanceUpdated(Map<String, dynamic> data) {
    print('WebSocket: Balance updated');
    // UI will handle updating balance display
  }

  /// Send ping to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          print('WebSocket: Ping error - $e');
        }
      }
    });
  }

  /// Handle disconnection and attempt reconnection
  void _handleDisconnect() {
    _pingTimer?.cancel();
    _channel = null;

    if (_shouldReconnect && _userId != null && _userType != null) {
      print('WebSocket: Attempting to reconnect in 5 seconds...');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        if (_shouldReconnect) {
          connect(_userId!, _userType!);
        }
      });
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    print('WebSocket: Disconnecting');
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _messageController?.close();
    _messageController = null;
    _userId = null;
    _userType = null;
  }

  /// Send message (optional, for future use)
  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        print('WebSocket: Send error - $e');
      }
    }
  }
}
