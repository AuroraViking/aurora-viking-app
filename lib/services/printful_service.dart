// lib/services/printful_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/print_product.dart';
import '../models/print_order.dart';

class PrintfulService {
  static const String _baseUrl = 'https://api.printful.com';
  static const String _apiKey = 'YOUR_PRINTFUL_API_KEY'; // Store securely

  /// Get available print products from Printful catalog
  static Future<List<PrintProduct>> getProductCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['result'] as List;

        return products.map((product) => PrintProduct.fromPrintfulApi(product)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching product catalog: ${e.toString()}');
    }
  }

  /// Get product variants (sizes, colors) for a specific product
  static Future<List<ProductVariant>> getProductVariants(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/$productId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final variants = data['result']['variants'] as List;

        return variants.map((variant) => ProductVariant.fromPrintfulApi(variant)).toList();
      } else {
        throw Exception('Failed to load variants: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching variants: ${e.toString()}');
    }
  }

  /// Create a new order with Printful
  static Future<PrintOrder> createOrder({
    required String userId,
    required List<OrderItem> items,
    required ShippingAddress address,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final orderData = {
        'recipient': {
          'name': address.fullName,
          'company': address.company,
          'address1': address.address1,
          'address2': address.address2,
          'city': address.city,
          'state_code': address.stateCode,
          'country_code': address.countryCode,
          'zip': address.zipCode,
          'phone': address.phone,
          'email': address.email,
        },
        'items': items.map((item) => item.toPrintfulApi()).toList(),
        'retail_costs': {
          'currency': 'USD',
          'subtotal': _calculateSubtotal(items),
          'discount': 0,
          'shipping': _calculateShipping(items, address),
          'tax': _calculateTax(items, address),
        },
        'external_id': userId, // Your internal order ID
      };

      if (metadata != null) {
        orderData['metadata'] = metadata;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: _getHeaders(),
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return PrintOrder.fromPrintfulApi(data['result'], userId);
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Order creation failed: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error creating order: ${e.toString()}');
    }
  }

  /// Confirm order for production
  static Future<void> confirmOrder(String printfulOrderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders/$printfulOrderId/confirm'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception('Order confirmation failed: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error confirming order: ${e.toString()}');
    }
  }

  /// Get order status and tracking info
  static Future<OrderStatus> getOrderStatus(String printfulOrderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$printfulOrderId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OrderStatusExtension.fromPrintfulApi(data['result']['status']);
      } else {
        throw Exception('Failed to get order status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching order status: ${e.toString()}');
    }
  }

  /// Upload image file for printing
  static Future<String> uploadImage(File imageFile, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/files'),
      );

      request.headers.addAll(_getHeaders());
      request.fields['type'] = 'default';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['result']['id'].toString();
      } else {
        final error = jsonDecode(responseBody);
        throw Exception('Image upload failed: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error uploading image: ${e.toString()}');
    }
  }

  /// Generate mockup for product with custom image
  static Future<String> generateMockup({
    required int productId,
    required int variantId,
    required String imageId,
    Map<String, dynamic>? printAreaSettings,
  }) async {
    try {
      final mockupData = {
        'variant_ids': [variantId],
        'format': 'jpg',
        'files': [
          {
            'placement': 'default',
            'image_id': imageId,
            'position': printAreaSettings ?? {
              'area_width': 1800,
              'area_height': 2400,
              'width': 1800,
              'height': 1200,
              'top': 600,
              'left': 0,
            }
          }
        ]
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/mockup-generator/create-task/$productId'),
        headers: _getHeaders(),
        body: jsonEncode(mockupData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final taskKey = data['result']['task_key'];

        // Poll for mockup completion
        return await _pollMockupResult(taskKey);
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Mockup generation failed: ${error['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error generating mockup: ${e.toString()}');
    }
  }

  /// Poll mockup generation result
  static Future<String> _pollMockupResult(String taskKey) async {
    for (int attempt = 0; attempt < 30; attempt++) {
      await Future.delayed(const Duration(seconds: 2));

      final response = await http.get(
        Uri.parse('$_baseUrl/mockup-generator/task?task_key=$taskKey'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];

        if (result['status'] == 'completed') {
          return result['result'][0]['mockup_url'];
        } else if (result['status'] == 'failed') {
          throw Exception('Mockup generation failed');
        }
      }
    }

    throw Exception('Mockup generation timeout');
  }

  /// Calculate estimated shipping cost
  static Future<double> calculateShipping({
    required List<OrderItem> items,
    required ShippingAddress address,
  }) async {
    try {
      final shippingData = {
        'recipient': {
          'country_code': address.countryCode,
          'state_code': address.stateCode,
        },
        'items': items.map((item) => {
          'variant_id': item.variantId,
          'quantity': item.quantity,
        }).toList(),
        'currency': 'USD',
        'locale': 'en_US',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/shipping/rates'),
        headers: _getHeaders(),
        body: jsonEncode(shippingData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['result'] as List;

        // Return cheapest standard shipping rate
        if (rates.isNotEmpty) {
          rates.sort((a, b) => a['rate'].compareTo(b['rate']));
          return double.parse(rates.first['rate']);
        }
      }

      // Fallback shipping cost
      return 15.99;
    } catch (e) {
      // Fallback shipping cost
      return 15.99;
    }
  }

  /// Get request headers for Printful API
  static Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Basic ${base64Encode(utf8.encode(_apiKey))}',
      'Content-Type': 'application/json',
      'X-PF-Store-Id': 'YOUR_STORE_ID', // If using store-specific API
    };
  }

  /// Calculate subtotal for items
  static double _calculateSubtotal(List<OrderItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  /// Calculate shipping cost (simplified)
  static double _calculateShipping(List<OrderItem> items, ShippingAddress address) {
    // Simplified shipping calculation
    // In production, use Printful's shipping rates API
    final itemCount = items.fold<int>(0, (sum, item) => sum + item.quantity);

    if (address.countryCode == 'US') {
      return itemCount <= 3 ? 4.99 : 7.99;
    } else {
      return itemCount <= 3 ? 9.99 : 15.99;
    }
  }

  /// Calculate tax (simplified)
  static double _calculateTax(List<OrderItem> items, ShippingAddress address) {
    // Simplified tax calculation
    // In production, use proper tax calculation service
    final subtotal = _calculateSubtotal(items);

    // US sales tax (varies by state)
    if (address.countryCode == 'US') {
      return subtotal * 0.08; // 8% average
    }

    // VAT for EU countries
    if (_isEUCountry(address.countryCode)) {
      return subtotal * 0.20; // 20% average VAT
    }

    return 0.0; // No tax for other countries
  }

  /// Check if country is in EU (simplified)
  static bool _isEUCountry(String countryCode) {
    const euCountries = ['DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'SE', 'DK'];
    return euCountries.contains(countryCode);
  }

  /// Get popular aurora-themed products
  static List<int> getAuroraProducts() {
    return [
      71,   // Unisex Heavy Cotton Tee
      146,  // Canvas Print (16×20″)
      19,   // Mug
      45,   // iPhone Case
      116,  // Throw Pillow
      142,  // Poster (18×24″)
      369,  // Framed Print
      287,  // Photo book
    ];
  }

  /// Get product recommendations based on photo
  static List<int> getRecommendedProducts(String photoType) {
    switch (photoType.toLowerCase()) {
      case 'landscape':
        return [146, 142, 369]; // Canvas, Poster, Framed Print
      case 'portrait':
        return [71, 19, 45]; // T-shirt, Mug, Phone Case
      default:
        return getAuroraProducts();
    }
  }
}