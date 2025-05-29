import 'package:flutter/material.dart';
import '../widgets/tour/tour_info_card.dart';
import '../widgets/tour/tour_photos_grid.dart';
import '../widgets/tour/tour_booking_card.dart';
import '../models/tour.dart';
import '../services/bokun_service.dart';
import '../services/firebase_service.dart';
import 'tour_auth_screen.dart';

class TourTab extends StatefulWidget {
  const TourTab({super.key});

  @override
  State<TourTab> createState() => _TourTabState();
}

class _TourTabState extends State<TourTab> {
  final _firebaseService = FirebaseService();
  final _bokunService = BokunService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isTourParticipant = false;
  List<Map<String, dynamic>> _tours = [];

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _isAuthenticated = _firebaseService.currentUser != null;
      if (_isAuthenticated) {
        _isTourParticipant = await _firebaseService.isTourParticipant();
        if (_isTourParticipant) {
          await _loadTours();
        }
      }
    } catch (e) {
      debugPrint('Error checking authentication: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTours() async {
    if (!_isAuthenticated || !_isTourParticipant) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tours = await _bokunService.getUpcomingTours();
      setState(() {
        _tours = tours.map((tour) => {
          'id': tour.id,
          'title': tour.name,
          'date': tour.date,
          'location': tour.location,
          'imageUrl': tour.photoUrls.isNotEmpty ? tour.photoUrls.first : null,
        }).toList();
      });
    } catch (e) {
      print('Failed to load tours: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAuthScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const TourAuthScreen(),
      ),
    );

    if (result == true) {
      _checkAuthentication();
    }
  }

  Future<void> _signOut() async {
    await _firebaseService.signOut();
    _checkAuthentication();
  }

  Future<void> _onVerifyBooking() async {
    final TextEditingController referenceController = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your booking reference number:'),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                hintText: 'e.g., AUR-65391772',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, referenceController.text.trim());
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (reference == null || reference.isEmpty) return;

    try {
      final result = await _firebaseService.verifyTourParticipant(reference);
      
      if (result != null) {
        // Show booking details
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Booking Verified'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Customer: [1m${result['customerName']}[0m'),
                  Text('Status: ${result['status']}'),
                  const SizedBox(height: 16),
                  const Text('Booked Tours:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(result['productBookings'] as List).map((booking) => Card(
                    child: ListTile(
                      title: Text(booking['name']),
                      subtitle: Text('Date: ${booking['date']}\nTime: ${booking['time']}'),
                      trailing: Text('Qty: ${booking['quantity']}'),
                    ),
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking not found. Please check your reference number and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Sign in to access your tours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _showAuthScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'SIGN IN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isTourParticipant) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No tour bookings found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please verify your tour booking to access your tours',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onVerifyBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'VERIFY BOOKING',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Tours',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _tours.isEmpty
          ? const Center(
              child: Text(
                'No tours found',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tours.length,
              itemBuilder: (context, index) {
                final tour = _tours[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      tour['title'] ?? 'Untitled Tour',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Date: ${tour['date'] ?? 'Not specified'}',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${tour['status'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: tour['status'] == 'Confirmed'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.tealAccent,
                    ),
                    onTap: () {
                      // TODO: Navigate to tour details
                    },
                  ),
                );
              },
            ),
    );
  }
} 