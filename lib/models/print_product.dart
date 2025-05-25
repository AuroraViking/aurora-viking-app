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
      return '\${min.toStringAsFixed(2)}';
    } else {
      return '\${min.toStringAsFixed(2)} - \${max.toStringAsFixed(2)}';
    }
  }
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