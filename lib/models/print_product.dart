// lib/models/print_product.dart
class PrintProduct {
  final int id;
  final String name;
  final String description;
  final String category;
  final List<String> imageUrls;
  final List<ProductVariant> variants;
  final Map<String, dynamic> printAreas;
  final bool isAvailable;

  PrintProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.variants,
    required this.printAreas,
    required this.isAvailable,
  });

  factory PrintProduct.fromPrintfulApi(Map<String, dynamic> json) {
    return PrintProduct(
      id: json['id'],
      name: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['type'] ?? '',
      imageUrls: List<String>.from(json['image'] != null ? [json['image']] : []),
      variants: [], // Loaded separately
      printAreas: Map<String, dynamic>.from(json['techniques'] ?? {}),
      isAvailable: json['is_discontinued'] != true,
    );
  }

  /// Get base price for this product
  double get basePrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  /// Get price range string
  String get priceRange {
    if (variants.isEmpty) return 'Price not available';

    final prices = variants.map((v) => v.price).toList();
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);

    if (min == max) {
      return '\$${min.toStringAsFixed(2)}';
    } else {
      return '\$${min.toStringAsFixed(2)} - \$${max.toStringAsFixed(2)}';
    }
  }

  // Add missing getters that PrintShop expects
  String get type => category; // PrintShop expects 'type' but you have 'category'
  List<String> get images => imageUrls; // PrintShop expects 'images' but you have 'imageUrls'
}

class ProductVariant {
  final int id;
  final int productId;
  final String name;
  final String size;
  final String color;
  final String colorCode;
  final double price;
  final String currency;
  final bool isAvailable;
  final String imageUrl;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.size,
    required this.color,
    required this.colorCode,
    required this.price,
    required this.currency,
    required this.isAvailable,
    required this.imageUrl,
  });

  factory ProductVariant.fromPrintfulApi(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      productId: json['product']['id'],
      name: json['name'] ?? '',
      size: json['size'] ?? '',
      color: json['color'] ?? '',
      colorCode: json['color_code'] ?? '#000000',
      price: double.parse(json['price'].toString()),
      currency: json['currency'] ?? 'USD',
      isAvailable: json['availability_status'] == 'active',
      imageUrl: json['image'] ?? '',
    );
  }

  String get displayName => '$color $size';
}

// Add the OrderItem class that PrintShop needs
class OrderItem {
  final int variantId;
  final String productName;
  final String variantName;
  final double price;
  final int quantity;
  final String? id;
  final int? productId;
  final String? imageUrl;
  final String? customImageId;
  final Map<String, dynamic>? printSettings;

  OrderItem({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.price,
    required this.quantity,
    this.id,
    this.productId,
    this.imageUrl,
    this.customImageId,
    this.printSettings,
  });

  // Add the copyWith method that PrintShop needs
  OrderItem copyWith({
    int? variantId,
    String? productName,
    String? variantName,
    double? price,
    int? quantity,
    String? id,
    int? productId,
    String? imageUrl,
    String? customImageId,
    Map<String, dynamic>? printSettings,
  }) {
    return OrderItem(
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      customImageId: customImageId ?? this.customImageId,
      printSettings: printSettings ?? this.printSettings,
    );
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      variantId: json['variantId'],
      productName: json['productName'],
      variantName: json['variantName'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'],
      id: json['id'],
      productId: json['productId'],
      imageUrl: json['imageUrl'],
      customImageId: json['customImageId'],
      printSettings: json['printSettings'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'productName': productName,
      'variantName': variantName,
      'price': price,
      'quantity': quantity,
      'id': id,
      'productId': productId,
      'imageUrl': imageUrl,
      'customImageId': customImageId,
      'printSettings': printSettings,
    };
  }
}