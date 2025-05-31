import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/bokun_service.dart';

class TourVerificationScreen extends StatefulWidget {
  const TourVerificationScreen({super.key});

  @override
  State<TourVerificationScreen> createState() => _TourVerificationScreenState();
}

class _TourVerificationScreenState extends State<TourVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Email verification
  final _emailController = TextEditingController();

  // Booking reference verification
  final _bookingReferenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Shared state
  final _firebaseService = FirebaseService();
  bool _isVerifying = false;
  String? _errorMessage;
  bool _apiConnectionTested = false;
  bool _apiConnectionOk = false;
  Map<String, dynamic>? _verificationResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _testApiConnection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _bookingReferenceController.dispose();
    super.dispose();
  }

  Future<void> _testApiConnection() async {
    try {
      final isConnected = await BokunService.testApiConnection();
      setState(() {
        _apiConnectionTested = true;
        _apiConnectionOk = isConnected;
      });
    } catch (e) {
      setState(() {
        _apiConnectionTested = true;
        _apiConnectionOk = false;
      });
      print('API connection test failed: $e');
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Check if input looks like a booking reference
  bool _looksLikeBookingReference(String input) {
    // Check if it contains "aur" or is numeric or alphanumeric
    final cleaned = input.toLowerCase().trim();
    return cleaned.contains('aur') ||
        RegExp(r'^\d+$').hasMatch(cleaned) ||
        RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(cleaned);
  }

  Future<void> _verifyByEmail() async {
    final emailInput = _emailController.text.trim();

    if (emailInput.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    // Check if user entered a booking reference in the email field
    if (_looksLikeBookingReference(emailInput) && !_isValidEmail(emailInput)) {
      setState(() {
        _errorMessage = 'It looks like you entered a booking reference. Please switch to the "Booking Reference" tab or enter your email address here.';
      });

      // Optionally, auto-switch to booking reference tab and populate the field
      _bookingReferenceController.text = emailInput;
      _tabController.animateTo(1);
      return;
    }

    if (!_isValidEmail(emailInput)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address (e.g., name@example.com)';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _verificationResult = null;
    });

    try {
      // Use the updated Firebase service method
      final firebaseResult = await _firebaseService.verifyTourParticipant(emailInput);

      if (firebaseResult != null && firebaseResult['isValid'] == true) {
        setState(() {
          _verificationResult = firebaseResult;
        });
        _showSuccessDialog('Email verification successful!');
      } else {
        setState(() {
          _errorMessage = 'No tour booking found for this email address. Please check your email or try the booking reference method.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _verifyByBookingReference() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _verificationResult = null;
    });

    try {
      final bookingReference = _bookingReferenceController.text.trim();
      print('🎯 Starting booking reference verification: $bookingReference');

      // Use the Firebase service method that calls Bokun internally
      final result = await _firebaseService.verifyTourParticipantByReference(bookingReference);

      if (result != null && result['isValid'] == true) {
        setState(() {
          _verificationResult = result;
        });
        _showSuccessDialog('Booking reference verified successfully!');
      } else {
        setState(() {
          _errorMessage = 'Booking reference not found. Please check the reference number and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.tealAccent, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Verification Successful!',
              style: TextStyle(color: Colors.tealAccent, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
            if (_verificationResult != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Details:',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_verificationResult!['customerName'] != null)
                Text(
                  'Customer: ${_verificationResult!['customerName']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (_verificationResult!['bookingId'] != null)
                Text(
                  'Booking ID: ${_verificationResult!['bookingId']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (_verificationResult!['status'] != null)
                Text(
                  'Status: ${_verificationResult!['status']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (_verificationResult!['productBookings'] != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Tours:',
                  style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                ..._verificationResult!['productBookings'].map<Widget>((booking) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '• ${booking['name']} (${booking['date']})',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                )),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(_verificationResult); // Return to previous screen with result
            },
            child: const Text(
              'CONTINUE',
              style: TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Debug Information', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'API Connection: ${_apiConnectionOk ? "✅ Connected" : "❌ Failed"}',
                style: TextStyle(
                  color: _apiConnectionOk ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Troubleshooting Tips:',
                style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Email Tab: Enter the email address used for booking\n'
                    '2. Reference Tab: Enter your booking reference (e.g., aur-65391772)\n'
                    '3. Check your booking confirmation email for both\n'
                    '4. Booking references may start with "aur-" or be just numbers\n'
                    '5. Contact support if both methods fail',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Common Issues:',
                style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Entering booking reference in email field\n'
                    '• Typos in email address\n'
                    '• Using wrong email (not the booking email)\n'
                    '• Missing or extra characters in reference',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text('Verify Tour Booking'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: _showDebugInfo,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.email_outlined),
              text: 'Email',
            ),
            Tab(
              icon: Icon(Icons.confirmation_number_outlined),
              text: 'Booking Reference',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // API Connection Status Banner
            if (_apiConnectionTested) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: _apiConnectionOk
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      _apiConnectionOk ? Icons.cloud_done : Icons.cloud_off,
                      color: _apiConnectionOk ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _apiConnectionOk
                          ? 'Bokun API Connected'
                          : 'Bokun API Connection Failed',
                      style: TextStyle(
                        color: _apiConnectionOk ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_apiConnectionOk) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: _testApiConnection,
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmailVerificationTab(),
                  _buildBookingReferenceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerificationTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify with Email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the email address you used when booking your aurora tour.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          // Example hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Example: john.smith@gmail.com',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'your.email@example.com',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.email_outlined, color: Colors.tealAccent),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _verifyByEmail(),
            ),
          ),
          if (_errorMessage != null && _tabController.index == 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyByEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isVerifying
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Verifying...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : const Text(
                'VERIFY EMAIL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingReferenceTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify with Booking Reference',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your booking reference number from your confirmation email.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            // Example hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Example: aur-65391772 or 65391772',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _bookingReferenceController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter booking reference',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.confirmation_number_outlined, color: Colors.tealAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.tealAccent),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your booking reference';
                }
                return null;
              },
              onFieldSubmitted: (_) => _verifyByBookingReference(),
            ),
            if (_errorMessage != null && _tabController.index == 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyByBookingReference,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Verifying...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : const Text(
                  'VERIFY BOOKING',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}