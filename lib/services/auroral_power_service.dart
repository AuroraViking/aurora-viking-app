import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuroraPowerPoint {
  final DateTime time;
  final double power;

  AuroraPowerPoint(this.time, this.power);

  @override
  String toString() => 'AuroraPowerPoint(time: $time, power: ${power.toStringAsFixed(1)} GW)';
}

class AuroralPowerService {
  static const int _maxDataPoints = 48; // 2 hours of candy-fueled data
  static const Duration _updateInterval = Duration(minutes: 1);

  // Singleton pattern (because sharing candy is caring)
  static final AuroralPowerService _instance = AuroralPowerService._internal();
  factory AuroralPowerService() => _instance;
  AuroralPowerService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final List<AuroraPowerPoint> _historicalData = [];
  Timer? _updateTimer;

  // Stream controller for real-time sugar rush updates
  final StreamController<Map<String, dynamic>> _dataController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get auroralPowerStream => _dataController.stream;
  List<AuroraPowerPoint> get historicalData => List.unmodifiable(_historicalData);

  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize the candy-powered aurora service
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    // print('🚀 Initializing Candy-Powered AuroralPowerService (Database-Only Mode)...');

    try {
      // Load delicious data from database (maintained by Edge Function)
      await _loadDataFromDatabase();

      // Start periodic sugar-checking updates
      _startPeriodicUpdates();

      // Set up real-time candy delivery subscription
      _setupRealtimeSubscription();

      _isInitialized = true;
      // print('✅ Candy-Powered AuroralPowerService initialized with \\${_historicalData.length} sweet data points');

      // Emit initial candy rush
      _emitCurrentData();

    } catch (e) {
      // print('❌ Service initialization failed (probably ran out of candy): $e');
      _isInitializing = false;
      rethrow;
    }

    _isInitializing = false;
  }

  Future<void> _loadDataFromDatabase() async {
    try {
      // print('📋 Loading aurora candy from database...');

      final response = await _supabase
          .from('aurora_readings')
          .select('timestamp, power, source')
          .order('timestamp', ascending: true)
          .limit(_maxDataPoints);

      _historicalData.clear();

      for (var row in response) {
        try {
          final time = DateTime.parse(row['timestamp']).toUtc();
          final power = double.parse(row['power'].toString());
          _historicalData.add(AuroraPowerPoint(time, power));
        } catch (e) {
          // print('⚠️ Error parsing candy-flavored database row: $e');
          continue;
        }
      }

      // print('📋 Loaded \\${_historicalData.length} delicious data points from database');

      // If no candy data, try to trigger the magical Edge Function
      if (_historicalData.isEmpty) {
        // print('⚠️ No candy in database. Attempting to summon Edge Function...');
        await _triggerEdgeFunction();
      }

    } catch (e) {
      // print('❌ Error loading candy data from database: $e');
      rethrow;
    }
  }

  Future<void> _triggerEdgeFunction() async {
    try {
      // print('🔄 Triggering Edge Function to collect initial candy...');

      final response = await _supabase.functions.invoke(
        'aurora-collector',
        headers: {'Content-Type': 'application/json'},
      );

      if (response.data != null && response.data['success'] == true) {
        // print('✅ Edge Function triggered successfully: \\${response.data['aurora_power']} GW of pure candy energy');

        // Wait for the candy to process
        await Future.delayed(const Duration(seconds: 3));
        await _loadDataFromDatabase();
      } else {
        // print('⚠️ Edge Function returned: \\${response.data}');
      }

    } catch (e) {
      // print('⚠️ Could not trigger Edge Function (maybe it needs more candy): $e');
      // Continue without triggering - data will come from cron job candy delivery
    }
  }

  void _setupRealtimeSubscription() {
    try {
      // print('🔔 Setting up real-time candy delivery subscription...');

      _supabase
          .channel('aurora_candy_changes')
          .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'aurora_readings',
        callback: (payload) {
          // print('📡 New candy delivered via real-time subscription');
          _handleRealtimeUpdate(payload);
        },
      )
          .subscribe();

    } catch (e) {
      // print('⚠️ Could not set up real-time candy subscription: $e');
      // Continue without real-time - periodic candy checks will still work
    }
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    try {
      final newRow = payload.newRecord;
      if (newRow != null) {
        final time = DateTime.parse(newRow['timestamp']).toUtc();
        final power = double.parse(newRow['power'].toString());
        final newPoint = AuroraPowerPoint(time, power);

        // Add new candy point and maintain sweetness limit
        _historicalData.add(newPoint);
        _historicalData.sort((a, b) => a.time.compareTo(b.time));

        // Keep only last 48 points (optimal candy concentration)
        if (_historicalData.length > _maxDataPoints) {
          _historicalData.removeAt(0);
        }

        // Emit updated candy data
        _emitCurrentData();
        // print('🔄 Real-time candy update: \\${power.toStringAsFixed(1)} GW at \\${time.toLocal()}');
      }
    } catch (e) {
      // print('⚠️ Error handling real-time candy update: $e');
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer?.cancel();

    _updateTimer = Timer.periodic(_updateInterval, (timer) async {
      if (_isInitialized) {
        try {
          await _checkForUpdates();
        } catch (e) {
          // print('⚠️ Periodic candy check failed: $e');
        }
      }
    });

    // print('⏰ Started periodic candy checks every \\${_updateInterval.inMinutes} minute(s)');
  }

  Future<void> _checkForUpdates() async {
    try {
      // Get timestamp of our latest candy
      DateTime? latestTime;
      if (_historicalData.isNotEmpty) {
        latestTime = _historicalData.last.time;
      }

      // Query for any newer candy - simplified approach
      final response = await _supabase
          .from('aurora_readings')
          .select('timestamp, power, source')
          .order('timestamp', ascending: true)
          .limit(_maxDataPoints);

      // Filter out old data points if we have existing data
      List<dynamic> newDataRows = response;
      if (latestTime != null) {
        newDataRows = response.where((row) {
          final rowTime = DateTime.parse(row['timestamp']).toUtc();
          return rowTime.isAfter(latestTime!);
        }).toList();
      }

      if (newDataRows.isNotEmpty) {
        // print('📡 Found \\${newDataRows.length} new candy data points');

        for (var row in newDataRows) {
          try {
            final time = DateTime.parse(row['timestamp']).toUtc();
            final power = double.parse(row['power'].toString());
            _historicalData.add(AuroraPowerPoint(time, power));
          } catch (e) {
            // print('⚠️ Error parsing new candy data point: $e');
            continue;
          }
        }

        // Sort and trim to optimal candy size limit
        _historicalData.sort((a, b) => a.time.compareTo(b.time));
        if (_historicalData.length > _maxDataPoints) {
          _historicalData.removeRange(0, _historicalData.length - _maxDataPoints);
        }

        // Emit updated candy data
        _emitCurrentData();
      }

    } catch (e) {
      // print('⚠️ Error checking for candy updates: $e');
    }
  }

  void _emitCurrentData() {
    if (_historicalData.isNotEmpty) {
      _dataController.add({
        'historicalData': _historicalData,
        'currentPower': _historicalData.last.power,
      });
    }
  }

  /// Manually refresh candy data from database
  Future<void> refresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    try {
      await _loadDataFromDatabase();
      _emitCurrentData();
      // print('🔄 Manual candy refresh completed');
    } catch (e) {
      // print('❌ Manual candy refresh failed: $e');
      rethrow;
    }
  }

  /// Get current auroral power (latest candy reading)
  double get currentPower {
    if (_historicalData.isEmpty) return 0.0;
    return _historicalData.last.power;
  }

  /// Get aurora activity description based on candy power level
  String getAuroralPowerDescription(double power) {
    if (power > 50) {
      return 'Major auroral candy explosion detected!';
    } else if (power > 30) {
      return 'Strong auroral candy activity detected';
    } else if (power > 20) {
      return 'Moderate auroral candy activity detected';
    } else if (power > 10) {
      return 'Minor auroral candy activity detected';
    } else {
      return 'No significant auroral candy activity';
    }
  }

  /// Get candy data coverage information
  String get dataCoverageInfo {
    if (_historicalData.isEmpty) return 'No candy available';

    final oldest = _historicalData.first.time;
    final newest = _historicalData.last.time;
    final duration = newest.difference(oldest);

    return 'Candy coverage: ${duration.inMinutes} minutes (${_historicalData.length} sweet points)';
  }

  /// Get candy data freshness information
  String get dataFreshnessInfo {
    if (_historicalData.isEmpty) return 'No candy';

    final lastUpdate = _historicalData.last.time;
    final now = DateTime.now().toUtc();
    final minutesAgo = now.difference(lastUpdate).inMinutes;

    if (minutesAgo < 2) {
      return 'Real-time candy';
    } else if (minutesAgo < 5) {
      return '$minutesAgo minutes ago (fresh candy)';
    } else if (minutesAgo < 60) {
      return '$minutesAgo minutes ago (candy getting stale)';
    } else {
      return 'Candy may be expired';
    }
  }

  /// Get candy system status
  String get systemStatus {
    if (_historicalData.isEmpty) return 'No candy';
    if (_historicalData.length < 20) return 'Partial candy';
    if (_historicalData.length >= 40) return 'Healthy candy levels';
    return 'Limited candy supply';
  }

  void dispose() {
    _updateTimer?.cancel();
    _dataController.close();
    _isInitialized = false;

    // Close real-time candy subscription
    _supabase.removeAllChannels();

    // print('🛑 Candy-Powered AuroralPowerService disposed (all candy consumed)');
  }
}