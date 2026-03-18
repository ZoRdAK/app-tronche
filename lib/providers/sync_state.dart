import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/send_queue_item.dart';
import '../services/database_service.dart';

class SyncState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _isOnline = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  int _pendingEmailCount = 0;
  List<SendQueueItem> _queueItems = [];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  int get pendingEmailCount => _pendingEmailCount;
  List<SendQueueItem> get queueItems => List.unmodifiable(_queueItems);

  set isSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  /// Starts listening to the connectivity_plus stream for network changes.
  void startMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });

    // Check current status immediately.
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
  }

  /// Loads pending counts from SQLite.
  Future<void> loadCounts() async {
    final all = await _db.getPendingQueueItems();
    _pendingSyncCount = all.where((i) => i.type == 'sync').length;
    _pendingEmailCount = all.where((i) => i.type == 'email').length;
    notifyListeners();
  }

  /// Loads all queue items from SQLite.
  Future<void> loadQueueItems() async {
    _queueItems = await _db.getAllQueueItems();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
