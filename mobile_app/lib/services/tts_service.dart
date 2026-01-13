import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  // Initialize TTS with configuration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set language to Indian English
      await _flutterTts.setLanguage("en-IN");

      // Set pitch to normal (1.0)
      await _flutterTts.setPitch(0.3);

      // Set speech rate to normal (0.5 is normal for most TTS engines)
      await _flutterTts.setSpeechRate(0.5);

      // Set volume to 0.5 (50%)
      await _flutterTts.setVolume(0.5);

      // Platform-specific configuration
      await _flutterTts.setSharedInstance(true);

      // iOS specific settings
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      _isInitialized = true;
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  // Check if voice notifications are enabled for user
  Future<bool> isVoiceNotificationEnabled(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('voice_notification_$userType') ??
        true; // Default enabled
  }

  // Enable/disable voice notifications
  Future<void> setVoiceNotificationEnabled(
      String userType, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_notification_$userType', enabled);
  }

  // Announce payment received (for merchants)
  Future<void> announcePaymentReceived({
    required double amount,
    required String userName,
    required String userType,
  }) async {
    if (!await isVoiceNotificationEnabled(userType)) return;

    await initialize();

    final message =
        'Payment received. Rupees ${amount.toStringAsFixed(2)} from $userName';
    await _speak(message);
  }

  // Announce balance added (for users)
  Future<void> announceBalanceAdded({
    required double amount,
    required String merchantName,
    required String userType,
  }) async {
    if (!await isVoiceNotificationEnabled(userType)) return;

    await initialize();

    final message =
        'Balance added. Rupees ${amount.toStringAsFixed(2)} added by $merchantName';
    await _speak(message);
  }

  // Announce balance deducted (for users)
  Future<void> announceBalanceDeducted({
    required double amount,
    required String merchantName,
    required String userType,
  }) async {
    if (!await isVoiceNotificationEnabled(userType)) return;

    await initialize();

    final message =
        'Balance deducted. Rupees ${amount.toStringAsFixed(2)} deducted by $merchantName';
    await _speak(message);
  }

  // Announce payment made (for users)
  Future<void> announcePaymentMade({
    required double amount,
    required String merchantName,
    required String userType,
  }) async {
    if (!await isVoiceNotificationEnabled(userType)) return;

    await initialize();

    final message =
        'Payment successful. Rupees ${amount.toStringAsFixed(2)} paid to $merchantName';
    await _speak(message);
  }

  // Core speak method
  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error speaking: $e');
    }
  }

  // Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  // Dispose TTS
  Future<void> dispose() async {
    await stop();
  }
}
