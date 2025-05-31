import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'forecast_tab.dart';
import 'my_photos_tab.dart';
import 'print_shop_tab.dart';
import 'tour_tab.dart';
import 'aurora_alerts_tab.dart';
import 'spot_aurora_screen.dart';
import '../services/firebase_service.dart';
import '../services/aurora_message_service.dart';
import '../widgets/user_badge.dart';
import 'tour_auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'satellite_map_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showSpotAuroraFAB = false;
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

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ForecastTab();
      case 1:
        return const SatelliteMapTab();
      case 2:
        return const AuroraAlertsTab();
      case 3:
        return const MyPhotosTab();
      case 4:
        return const PrintShopTab();
      case 5:
        return const TourTab();
      default:
        return const ForecastTab();
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

    return StreamBuilder<User?>(
      stream: _firebaseService.auth.authStateChanges(),
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.hasData;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0F1C),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Aurora Viking',
              style: TextStyle(color: Colors.white),
            ),
            actions: const [
              Padding(
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
          bottomNavigationBar: isAuthenticated
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0A0F1C).withOpacity(0.8),
                        const Color(0xFF0A0F1C),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Container(
                      height: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D4AA).withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(0, Icons.radar, 'Forecast'),
                          _buildNavItem(1, Icons.satellite_alt, 'Satellite Map'),
                          _buildNavItem(2, Icons.people_outline, 'Community'),
                          _buildNavItem(3, Icons.photo_library_outlined, 'Photos'),
                          _buildNavItem(4, Icons.print_outlined, 'Print'),
                          _buildNavItem(5, Icons.tour, 'Tour'),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          floatingActionButton: isAuthenticated && _showSpotAuroraFAB
              ? _buildSpotAuroraFAB()
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  // Simple FAB widget
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
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SPOT AURORA!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getConditionsText(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D4AA).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withOpacity(0.6),
                size: isSelected ? 26 : 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00D4AA)
                    : Colors.white.withOpacity(0.6),
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}