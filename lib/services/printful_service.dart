import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/print_product.dart';
import 'config_service.dart';

class PrintfulService {
  static final PrintfulService _instance = PrintfulService._internal();
  factory PrintfulService() => _instance;
  
  static const String _baseUrl = 'https://api.printful.com';
  late final String _authToken;

  PrintfulService._internal() {
    _authToken = base64Encode(
      utf8.encode('${ConfigService.printfulClientId}:${ConfigService.printfulSecretKey}')
    );
  }

  // PRODUCT CATALOG METHODS

  // Get all available products
  Future<List<PrintProduct>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final products = <PrintProduct>[];

        for (final item in data['result']) {
          products.add(PrintProduct.fromPrintfulApi(item));
        }

        return products;
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
      return _getMockProducts(); // Fallback to mock data
    }
  }

  // Get product variants (sizes, colors, etc.)
  Future<List<ProductVariant>> getProductVariants(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/$productId'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final variants = <ProductVariant>[];

        for (final item in data['result']['variants']) {
          variants.add(ProductVariant.fromPrintfulApi(item));
        }

        return variants;
      } else {
        throw Exception('Failed to load variants: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching variants: $e');
      return [];
    }
  }

  // MOCKUP GENERATION

  // Generate product mockup with user's aurora photo
  Future<String?> generateMockup({
    required int productId,
    required int variantId,
    required String imageUrl,
    Map<String, dynamic>? options,
  }) async {
    try {
      final body = {
        'variant_ids': [variantId],
        'files': [
          {
            'placement': 'front',
            'image_url': imageUrl,
            'position': {
              'area_width': 1800,
              'area_height': 2400,
              'width': 1800,
              'height': 1200,
              'top': 600,
              'left': 0,
            }
          }
        ],
        'options': options ?? {},
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/mockup-generator/create-task/$productId'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final taskKey = data['result']['task_key'];

        // Poll for completion
        return await _waitForMockupCompletion(taskKey);
      } else {
        throw Exception('Failed to create mockup: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating mockup: $e');
      return null;
    }
  }

  // Wait for mockup generation to complete
  Future<String?> _waitForMockupCompletion(String taskKey) async {
    for (int i = 0; i < 30; i++) { // Wait up to 30 seconds
      await Future.delayed(const Duration(seconds: 1));

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/mockup-generator/task?task_key=$taskKey'),
          headers: {
            'Authorization': 'Basic $_authToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final status = data['result']['status'];

          if (status == 'completed') {
            final mockups = data['result']['mockups'] as List;
            if (mockups.isNotEmpty) {
              return mockups.first['mockup_url'];
            }
          } else if (status == 'failed') {
            throw Exception('Mockup generation failed');
          }
        }
      } catch (e) {
        print('Error checking mockup status: $e');
      }
    }

    return null; // Timeout
  }

  // SHIPPING & PRICING

  // Calculate shipping rates - simplified
  Future<List<ShippingRate>> calculateShipping({
    required Map<String, dynamic> address,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final body = {
        'recipient': address,
        'items': items,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/shipping/rates'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = <ShippingRate>[];

        for (final rate in data['result']) {
          rates.add(ShippingRate.fromJson(rate));
        }

        return rates;
      } else {
        throw Exception('Failed to calculate shipping: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating shipping: $e');
      return _getMockShippingRates();
    }
  }

  // ORDER MANAGEMENT

  // Create order - simplified to return order ID
  Future<String?> createOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    required String shippingMethod,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'recipient': shippingAddress,
        'items': items,
        'shipping': shippingMethod,
        'external_id': 'aurora_${DateTime.now().millisecondsSinceEpoch}',
        'metadata': metadata ?? {},
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result']['id'].toString();
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  // Get order status - simplified
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      } else {
        throw Exception('Failed to get order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  // Cancel order
  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error canceling order: $e');
      return false;
    }
  }

  // AURORA-SPECIFIC METHODS

  // Get aurora-themed products
  Future<List<PrintProduct>> getAuroraProducts() async {
    final allProducts = await getProducts();

    // Filter for products suitable for aurora photos
    return allProducts.where((product) =>
    product.type == 'poster' ||
        product.type == 'canvas' ||
        product.type == 'mug' ||
        product.type == 'phone-case' ||
        product.type == 't-shirt'
    ).toList();
  }

  // Create aurora photo print package
  Future<Map<String, dynamic>> createAuroraPackage({
    required String photoUrl,
    required String customerName,
    required String tourDate,
    required Map<String, dynamic> address,
  }) async {
    try {
      // Get recommended products for aurora photos
      final products = await getAuroraProducts();

      if (products.isEmpty) {
        return {};
      }

      // Find poster and canvas products
      final posters = products.where((p) => p.type == 'poster').toList();
      final canvases = products.where((p) => p.type == 'canvas').toList();

      final result = <String, dynamic>{};

      if (posters.isNotEmpty) {
        final poster = posters.first;
        final posterMockup = await generateMockup(
          productId: poster.id,
          variantId: poster.variants.isNotEmpty ? poster.variants.first.id : 0,
          imageUrl: photoUrl,
        );

        result['poster'] = {
          'product': poster,
          'mockup': posterMockup,
        };
      }

      if (canvases.isNotEmpty) {
        final canvas = canvases.first;
        final canvasMockup = await generateMockup(
          productId: canvas.id,
          variantId: canvas.variants.isNotEmpty ? canvas.variants.first.id : 0,
          imageUrl: photoUrl,
        );

        result['canvas'] = {
          'product': canvas,
          'mockup': canvasMockup,
        };
      }

      result['metadata'] = {
        'customerName': customerName,
        'tourDate': tourDate,
        'photoUrl': photoUrl,
      };

      return result;
    } catch (e) {
      print('Error creating aurora package: $e');
      return {};
    }
  }

  // MOCK DATA FOR DEVELOPMENT

  List<PrintProduct> _getMockProducts() {
    return [
      PrintProduct(
        id: 1,
        name: 'Aurora Poster',
        description: 'High-quality poster perfect for aurora photos',
        category: 'poster',
        imageUrls: ['https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Poster'],
        variants: [
          ProductVariant(
            id: 101,
            productId: 1,
            name: '18×24 inches',
            size: '18×24"',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 25.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Poster',
          ),
          ProductVariant(
            id: 102,
            productId: 1,
            name: '24×36 inches',
            size: '24×36"',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 35.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Poster',
          ),
        ],
        printAreas: {},
        isAvailable: true,
      ),
      PrintProduct(
        id: 2,
        name: 'Aurora Canvas',
        description: 'Premium canvas print for your aurora memories',
        category: 'canvas',
        imageUrls: ['https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Canvas'],
        variants: [
          ProductVariant(
            id: 201,
            productId: 2,
            name: '16×20 inches',
            size: '16×20"',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 45.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Canvas',
          ),
          ProductVariant(
            id: 202,
            productId: 2,
            name: '20×30 inches',
            size: '20×30"',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 65.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x600/0f1419/ffffff?text=Aurora+Canvas',
          ),
        ],
        printAreas: {},
        isAvailable: true,
      ),
      PrintProduct(
        id: 3,
        name: 'Aurora Mug',
        description: 'Start your day with aurora magic',
        category: 'mug',
        imageUrls: ['https://via.placeholder.com/400x400/0f1419/ffffff?text=Aurora+Mug'],
        variants: [
          ProductVariant(
            id: 301,
            productId: 3,
            name: '11oz Ceramic Mug',
            size: '11oz',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 15.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x400/0f1419/ffffff?text=Aurora+Mug',
          ),
          ProductVariant(
            id: 302,
            productId: 3,
            name: '15oz Ceramic Mug',
            size: '15oz',
            color: 'White',
            colorCode: '#FFFFFF',
            price: 18.00,
            currency: 'USD',
            isAvailable: true,
            imageUrl: 'https://via.placeholder.com/400x400/0f1419/ffffff?text=Aurora+Mug',
          ),
        ],
        printAreas: {},
        isAvailable: true,
      ),
    ];
  }

  List<ShippingRate> _getMockShippingRates() {
    return [
      ShippingRate(
        id: 'standard',
        name: 'Standard Shipping',
        rate: 5.99,
        currency: 'USD',
        minDeliveryDays: 7,
        maxDeliveryDays: 14,
      ),
      ShippingRate(
        id: 'express',
        name: 'Express Shipping',
        rate: 12.99,
        currency: 'USD',
        minDeliveryDays: 3,
        maxDeliveryDays: 7,
      ),
    ];
  }

  // UTILITY METHODS

  // Upload file to Printful for printing
  Future<String?> uploadFile(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/files'),
      );

      request.headers.addAll({
        'Authorization': 'Basic $_authToken',
        'Content-Type': 'application/json',
      });
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);
        return data['result']['id'];
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Get product pricing with quantity discounts
  Future<Map<String, dynamic>> getProductPricing({
    required int variantId,
    required int quantity,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/variant/$variantId'),
        headers: {
          'Authorization': 'Basic $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final variant = data['result']['variant'];

        return {
          'retail_price': variant['retail_price'],
          'price': variant['price'],
          'currency': variant['currency'],
          'quantity_discount': _calculateQuantityDiscount(quantity),
        };
      } else {
        throw Exception('Failed to get pricing: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting pricing: $e');
      return {};
    }
  }

  double _calculateQuantityDiscount(int quantity) {
    if (quantity >= 10) return 0.15; // 15% discount
    if (quantity >= 5) return 0.10;  // 10% discount
    if (quantity >= 3) return 0.05;  // 5% discount
    return 0.0; // No discount
  }
}

// Supporting classes for shipping rates
class ShippingRate {
  final String id;
  final String name;
  final double rate;
  final String currency;
  final int minDeliveryDays;
  final int maxDeliveryDays;

  ShippingRate({
    required this.id,
    required this.name,
    required this.rate,
    required this.currency,
    required this.minDeliveryDays,
    required this.maxDeliveryDays,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> json) {
    return ShippingRate(
      id: json['id'],
      name: json['name'],
      rate: (json['rate'] as num).toDouble(),
      currency: json['currency'],
      minDeliveryDays: json['minDeliveryDays'] ?? 7,
      maxDeliveryDays: json['maxDeliveryDays'] ?? 14,
    );
  }
}