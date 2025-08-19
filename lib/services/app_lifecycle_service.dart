import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/sync_providers.dart' as sync;
import 'package:babblelon/providers/profile_providers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to handle app lifecycle events and trigger appropriate syncs
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  Ref? _ref;
  DateTime? _lastSyncTime;
  final Duration _syncDebounceInterval = const Duration(seconds: 30);

  /// Initialize the lifecycle service with a ref
  void initialize(Ref ref) {
    _ref = ref;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🔄 AppLifecycleService: Initialized with lifecycle observer');
  }

  /// Dispose of the lifecycle service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ref = null;
    debugPrint('🔄 AppLifecycleService: Disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('🔄 AppLifecycleService: App lifecycle changed to: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 AppLifecycleService: App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 AppLifecycleService: App detached');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 AppLifecycleService: App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 AppLifecycleService: App hidden');
        break;
    }
  }

  /// Handle app resume events
  void _onAppResumed() {
    debugPrint('📱 AppLifecycleService: App resumed');
    
    if (_ref == null) {
      debugPrint('⚠️ AppLifecycleService: No ref available for sync');
      return;
    }

    // Debounce sync calls to avoid excessive syncing
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncDebounceInterval) {
      debugPrint('🔄 AppLifecycleService: Sync debounced (last sync: $_lastSyncTime)');
      return;
    }

    _lastSyncTime = now;
    _triggerAppResumeSync();
  }

  /// Trigger sync when app resumes
  void _triggerAppResumeSync() {
    debugPrint('🔄 AppLifecycleService: Triggering app resume sync...');
    
    Future.microtask(() async {
      try {
        // Check connectivity first
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        final hasConnectivity = !connectivityResults.contains(ConnectivityResult.none);
        
        if (!hasConnectivity) {
          debugPrint('📶 AppLifecycleService: No connectivity, skipping sync');
          return;
        }

        debugPrint('📶 AppLifecycleService: Connectivity available, proceeding with sync');
        
        final syncService = _ref!.read(sync.syncServiceProvider);
        await syncService.syncAll();
        debugPrint('✅ AppLifecycleService: App resume sync completed');
        
        // Refresh profile completion provider
        final refreshProfile = _ref!.read(profileRefreshProvider);
        refreshProfile();
        debugPrint('✅ AppLifecycleService: Profile completion refreshed after app resume');
      } catch (e) {
        debugPrint('💥 AppLifecycleService: App resume sync failed: $e');
      }
    });
  }

  /// Manually trigger sync (for testing or forced refresh)
  void triggerManualSync() {
    debugPrint('🔄 AppLifecycleService: Manual sync triggered');
    _lastSyncTime = null; // Reset debounce
    _triggerAppResumeSync();
  }
}

/// Provider for the app lifecycle service
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  final service = AppLifecycleService();
  service.initialize(ref);
  
  // Dispose when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});