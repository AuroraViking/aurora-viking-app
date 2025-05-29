import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/tour.dart';

class BokunService {
  // TODO: Securely fetch or store API keys, do not ship secrets in app code
  static const String _accessKey = 'ac9b97bc985e438ea1dac47ac46a3f5e';
  static const String _secretKey = '71224940931d43f996cc41a5c0ee943d';
  static const String _baseUrl = 'https://api.bokun.io/v1';

  // Generate HMAC-SHA1 signature for Bokun API authentication
  String _generateSignature(String date, String path) {
    final key = utf8.encode(_secretKey);
    final message = utf8.encode('$date\n$path');
    final hmac = Hmac(sha1, key);
    final signature = hmac.convert(message);
    return base64.encode(signature.bytes);
  }

  // Get authentication headers for Bokun API
  Map<String, String> _getAuthHeaders(String path) {
    // Format date as 'yyyy-MM-dd HH:mm:ss'
    final now = DateTime.now().toUtc();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final signature = _generateSignature(date, path);
    
    print('🔑 Using date format: $date');
    print('🔑 Generated signature: $signature');
    
    return {
      'X-Bokun-Date': date,
      'X-Bokun-AccessKey': _accessKey,
      'X-Bokun-Signature': signature,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<Tour>> getUpcomingTours() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders'),
        headers: _getAuthHeaders('/orders'),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> orders = data['orders'] ?? [];
        
        return orders.map((order) {
          final product = order['product'] ?? {};
          final pickup = order['pickup'] ?? {};
          
          return Tour(
            id: order['id']?.toString() ?? '',
            name: product['title'] ?? 'Unknown Tour',
            date: DateTime.parse(pickup['date'] ?? DateTime.now().toIso8601String()),
            location: pickup['location']?['name'] ?? 'Location TBD',
            description: product['description'] ?? 'No description available',
            bookingReference: order['reference'] ?? '',
            photoUrls: (product['photos'] as List<dynamic>?)?.map((photo) => photo['url'] as String).toList() ?? [],
            bookingDetails: {
              'pickupLocation': pickup['location']?['name'] ?? 'TBD',
              'pickupTime': pickup['time'] ?? 'TBD',
              'duration': product['duration'] ?? 'TBD',
              'groupSize': '${order['numberOfTravelers'] ?? 0} people',
            },
          );
        }).toList();
      } else {
        print('Failed to fetch tours: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch tours: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching tours: $e');
      rethrow;
    }
  }

  Future<List<Tour>> getPastTours() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/past'),
        headers: _getAuthHeaders('/orders/past'),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> orders = data['orders'] ?? [];
        
        return orders.map((order) {
          final product = order['product'] ?? {};
          final pickup = order['pickup'] ?? {};
          
          return Tour(
            id: order['id']?.toString() ?? '',
            name: product['title'] ?? 'Unknown Tour',
            date: DateTime.parse(pickup['date'] ?? DateTime.now().toIso8601String()),
            location: pickup['location']?['name'] ?? 'Location TBD',
            description: product['description'] ?? 'No description available',
            bookingReference: order['reference'] ?? '',
            photoUrls: (product['photos'] as List<dynamic>?)?.map((photo) => photo['url'] as String).toList() ?? [],
            isPast: true,
            bookingDetails: {
              'pickupLocation': pickup['location']?['name'] ?? 'TBD',
              'pickupTime': pickup['time'] ?? 'TBD',
              'duration': product['duration'] ?? 'TBD',
              'groupSize': '${order['numberOfTravelers'] ?? 0} people',
            },
          );
        }).toList();
      } else {
        print('Failed to fetch past tours: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch past tours: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching past tours: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTourDetails(String bookingReference) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$bookingReference'),
        headers: _getAuthHeaders('/orders/$bookingReference'),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final order = data['order'] ?? {};
        final product = order['product'] ?? {};
        final pickup = order['pickup'] ?? {};
        
        return {
          'bookingReference': bookingReference,
          'status': order['status'] ?? 'unknown',
          'pickupLocation': pickup['location']?['name'] ?? 'TBD',
          'pickupTime': pickup['time'] ?? 'TBD',
          'duration': product['duration'] ?? 'TBD',
          'groupSize': '${order['numberOfTravelers'] ?? 0} people',
          'price': '${order['totalPrice'] ?? 0} ${order['currency'] ?? 'EUR'}',
          'currency': order['currency'] ?? 'EUR',
          'cancellationPolicy': product['cancellationPolicy'] ?? 'Contact for details',
        };
      } else {
        print('Failed to fetch tour details: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch tour details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching tour details: $e');
      rethrow;
    }
  }

  Future<bool> verifyEmail(String email) async {
    try {
      print('🔍 Verifying email: $email');
      
      // First try to verify using the booking reference
      final bookingRef = 'AUR-65391772'; // Using the provided booking reference
      print('🔑 Checking booking reference: $bookingRef');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$bookingRef'),
        headers: _getAuthHeaders('/orders/$bookingRef'),
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final order = data['order'];
        
        if (order != null) {
          final status = order['status']?.toString().toLowerCase();
          final orderEmail = order['customer']?['email']?.toString().toLowerCase();
          
          print('📊 Order found with status: $status');
          print('📧 Order email: $orderEmail');
          
          // Verify that the email matches and status is valid
          final isValid = orderEmail == email.toLowerCase() && 
                         (status == 'confirmed' || status == 'pending');
          
          print('✅ Order verification result: $isValid');
          return isValid;
        }
      }
      
      print('❌ Failed to verify booking: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to verify booking: ${response.statusCode}');
    } catch (e) {
      print('❌ Error verifying booking: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> verifyBookingReference(String reference) async {
    try {
      print('🔍 Verifying booking reference: $reference');
      
      // Use the orders endpoint with a query parameter
      final path = '/orders?reference=$reference';
      final headers = _getAuthHeaders(path);
      
      print('🔑 Using headers: $headers');
      print('🔑 Making request to: $_baseUrl$path');
      
      final response = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final orders = data['orders'] as List<dynamic>;
        
        if (orders.isNotEmpty) {
          final order = orders.first;
          print('✅ Found matching order');
          print('📊 Order status: ${order['status']}');
          
          // Extract order details
          final status = order['status']?.toString().toLowerCase();
          final isValid = status == 'confirmed' || status == 'pending';
          
          // Get product details
          final product = order['product'] ?? {};
          final pickup = order['pickup'] ?? {};
          
          return {
            'isValid': isValid,
            'status': status,
            'customerName': order['customerName'] ?? 'Unknown',
            'productBookings': [{
              'name': product['title'] ?? 'Unknown Tour',
              'date': pickup['date'] ?? 'TBD',
              'time': pickup['time'] ?? 'TBD',
              'quantity': order['numberOfTravelers'] ?? 1,
              'status': status,
            }],
            'bookingId': order['id']?.toString(),
            'reference': reference,
          };
        }
      }
      
      print('❌ Failed to verify booking: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('❌ Error verifying booking: $e');
      return null;
    }
  }
} 