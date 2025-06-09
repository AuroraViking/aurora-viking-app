import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'forecast_tab.dart';
import 'my_photos_tab.dart';
import 'prints_tab.dart' as prints;
import 'aurora_alerts_tab.dart';
import 'spot_aurora_screen.dart';
import 'camera_debug_screen.dart'; // Add this import
import '../services/firebase_service.dart';
import '../widgets/user_badge.dart';
import 'tour_auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/light_pollution_service.dart';
import '../services/sunrise_sunset_service.dart';
import '../services/moon_service.dart';
import '../widgets/forecast/bortle_map.dart';
import '../widgets/forecast/cloud_forecast_map.dart';
import '../services/auroral_power_service.dart';
import '../widgets/forecast/auroral_power_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showSpotAuroraFAB = true;
  bool _isInitialized = false;
  String? _errorMessage;

  // Aurora conditions for FAB visibility
  double _currentBzH = 0.0;
  double _currentKp = 0.0;

  late AnimationController _fabAnimationController;
  late AnimationController _navigationAnimationController;

  // Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _navigationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _navigationAnimationController.forward();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize Firebase (automatically signs in as guest)
      await FirebaseService.initialize();

      // Subscribe to aurora alerts for Iceland
      await _firebaseService.subscribeToAuroraAlerts('iceland');

      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });

      print('✅ Services initialized successfully');
      print('👤 User: ${_firebaseService.userDisplayName}');
    } catch (e) {
      print('❌ Service initialization failed: $e');
      setState(() {
        _isInitialized = false;
        _errorMessage = 'Failed to initialize services: $e';
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _navigationAnimationController.dispose();
    super.dispose();
  }

  // Callback from ForecastTab when conditions change
  void _onConditionsUpdate({
    required double bzH,
    required double kp,
    required double speed,
    required double density,
  }) {
    setState(() {
      _currentBzH = bzH;
      _currentKp = kp;
    });

    // Show FAB when aurora conditions are good
    final shouldShow = _shouldShowSpotAuroraFAB(bzH, kp);
    if (shouldShow != _showSpotAuroraFAB) {
      setState(() {
        _showSpotAuroraFAB = shouldShow;
      });

      if (shouldShow) {
        _fabAnimationController.repeat();
        _triggerHapticFeedback();
      } else {
        _fabAnimationController.stop();
      }
    }
  }

  bool _shouldShowSpotAuroraFAB(double bzH, double kp) {
    // Show FAB when conditions are favorable for aurora
    return bzH > 2.0 || kp >= 3.0;
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ForecastTab();
      case 1:
        return const AuroraAlertsTab();
      case 2:
        return const MyPhotosTab();
      case 3:
        return const prints.PrintsTab();
      default:
        return const ForecastTab();
    }
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: [
        _buildNavItem(0, Icons.radar, 'Forecast'),
        _buildNavItem(1, Icons.notifications, 'Aurora Sightings'),
        _buildNavItem(2, Icons.photo_library, 'Photos'),
        _buildNavItem(3, Icons.print, 'Prints'),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return NavigationDestination(
      icon: Icon(
        icon,
        color: isSelected ? Colors.tealAccent : Colors.white70,
      ),
      label: label,
    );
  }

  Future<void> _onSpotAurora() async {
    try {
      // Navigate to your existing spot aurora screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpotAuroraScreen(
            currentBzH: _currentBzH,
            currentKp: _currentKp,
          ),
        ),
      );

      // Show success message after returning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌟 Aurora sighting shared with the community!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Switch to Community tab to see the sighting
      setState(() {
        _selectedIndex = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add camera debug function
  void _openCameraDebug() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraDebugScreen(),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });

      // Haptic feedback
      HapticFeedback.selectionClick();

      // Restart navigation animation
      _navigationAnimationController.reset();
      _navigationAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0F1C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _errorMessage ?? 'Initializing services...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeServices,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return StreamBuilder<firebase_auth.User?>(
      stream: _firebaseService.auth.authStateChanges(),
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.hasData;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0F1C),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Aurora Viking – Where the Lights Come Alive'),
                    content: const Text(
                        'Aurora Viking is your trusted guide to the Northern Lights. Whether you\'re chasing the aurora from afar or standing beneath them, our app gives you the tools to witness nature\'s most stunning light show.\n\n'
                            'Get real-time aurora forecasts, smart alerts, and live community sightings — all in one place. Track the lights, share the moment, and join a growing community of aurora enthusiasts across the globe.\n\n'
                            'As a dedicated Northern Lights tour operator based in Iceland, we don\'t just predict the aurora — we hunt it. Our expert guides take you beyond the clouds and into the heart of the auroral zone, capturing memories that last a lifetime.\n\n'
                            'Curious about joining one of our tours?\n'
                            'Tap the link to learn more: '
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final Uri url = Uri.parse('https://auroraviking.com');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            throw 'Could not launch $url';
                          }
                        },
                        child: const Text('auroraviking.com'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Image.asset(
                'assets/images/WhiteonTransparent.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              // Add debug button here (temporary for testing)
              if (isAuthenticated)
                IconButton(
                  icon: const Icon(
                    Icons.bug_report,
                    color: Colors.orange,
                    size: 24,
                  ),
                  onPressed: _openCameraDebug,
                  tooltip: 'Camera Debug',
                ),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: UserBadge(),
              ),
            ],
          ),
          body: !isAuthenticated
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 64,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to Aurora Viking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in to continue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TourAuthScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
              : AnimatedBuilder(
            animation: _navigationAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _navigationAnimationController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _navigationAnimationController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: _buildBody(),
                ),
              );
            },
          ),
          bottomNavigationBar: isAuthenticated ? _buildNavigationBar() : null,
          floatingActionButton: FloatingActionButton(
            onPressed: _refreshData,
            backgroundColor: Colors.tealAccent,
            child: const Icon(Icons.refresh),
          ),
        );
      },
    );
  }

  Widget _buildSpotAuroraFAB() {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_fabAnimationController.value * 0.1),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4AA).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: _fabAnimationController.value * 10,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _onSpotAurora();
              },
              backgroundColor: const Color(0xFF00D4AA),
              elevation: 8,
              icon: AnimatedRotation(
                turns: _fabAnimationController.value,
                duration: const Duration(milliseconds: 100),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              label: const Text(
                'SPOT AURORA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getConditionsText() {
    if (_currentBzH > 4.5) {
      return 'Strong conditions!';
    } else if (_currentBzH > 3.0) {
      return 'Good conditions!';
    } else if (_currentKp >= 4.0) {
      return 'High Kp activity!';
    } else {
      return 'Aurora possible!';
    }
  }

  Future<void> _refreshData() async {
    // Implement the logic to refresh data
  }
}