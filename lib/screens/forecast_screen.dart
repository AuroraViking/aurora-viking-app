import 'package:flutter/material.dart';
import '../services/substorm_alert_service.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final SubstormAlertService _substormService = SubstormAlertService();
  Map<String, dynamic>? _substormStatus;
  bool _isLoadingSubstorm = true;

  @override
  void initState() {
    super.initState();
    _loadSubstormStatus();
  }

  Future<void> _loadSubstormStatus() async {
    setState(() => _isLoadingSubstorm = true);
    try {
      final status = await _substormService.getSubstormStatus();
      setState(() {
        _substormStatus = status;
        _isLoadingSubstorm = false;
      });
    } catch (e) {
      print('Error loading substorm status: $e');
      setState(() => _isLoadingSubstorm = false);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Aurora Forecast',
            style: TextStyle(color: Colors.white),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nowcast'),
              Tab(text: 'Forecast'),
              Tab(text: 'Alerts'),
            ],
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.tealAccent,
          ),
        ),
        body: TabBarView(
          children: [
            // Nowcast Tab
            SingleChildScrollView(
              child: Column(
                children: [
                  // Aurora Conditions Message Box
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Aurora Conditions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No significant auroral activity expected at this time.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Substorm Tracker
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _substormStatus?['isActive'] == true 
                                    ? Icons.flash_on 
                                    : Icons.flash_off,
                                color: _substormStatus?['isActive'] == true 
                                    ? Colors.amber 
                                    : Colors.white70,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Substorm Tracker',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isLoadingSubstorm)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.tealAccent,
                              ),
                            )
                          else if (_substormStatus == null)
                            const Text(
                              'Unable to load substorm data',
                              style: TextStyle(color: Colors.white70),
                            )
                          else ...[
                            Text(
                              _substormService.getSubstormDescription(
                                _substormStatus!['aeValue'] as int,
                              ),
                              style: TextStyle(
                                color: _substormStatus!['isActive'] == true 
                                    ? Colors.amber 
                                    : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AE Index: ${_substormStatus!['aeValue']} nT',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Last updated: ${_formatTimestamp(_substormStatus!['timestamp'] as DateTime)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadSubstormStatus,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent.withOpacity(0.1),
                                foregroundColor: Colors.tealAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bz Chart
                  Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text(
                        'Bz Chart',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  // Current Conditions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Conditions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Add your existing current conditions content here
                        ],
                      ),
                    ),
                  ),
                  // Satellite Cloud Cover Map
                  Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text(
                        'Satellite Cloud Cover Map',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Forecast Tab
            const Center(
              child: Text(
                'Forecast Tab',
                style: TextStyle(color: Colors.white),
              ),
            ),
            // Alerts Tab
            const Center(
              child: Text(
                'Alerts Tab',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 