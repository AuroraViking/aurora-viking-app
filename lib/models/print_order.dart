// lib/models/print_order.dart

enum OrderStatus {
  draft,
  pending,
  confirmed,
  inProduction,
  shipped,
  delivered,
  cancelled,
  failed,
}

extension OrderStatusExtension on OrderStatus {
  static OrderStatus fromPrintfulApi(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return OrderStatus.draft;
      case 'pending': return OrderStatus.pending;
      case 'confirmed': return OrderStatus.confirmed;
      case 'inproduction': return OrderStatus.inProduction;
      case 'shipped': return OrderStatus.shipped;
      case 'delivered': return OrderStatus.delivered;
      case 'cancelled': return OrderStatus.cancelled;
      case 'failed': return OrderStatus.failed;
      default: return OrderStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.draft: return 'Draft';
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.confirmed: return 'Confirmed';
      case OrderStatus.inProduction: return 'In Production';
      case OrderStatus.shipped: return 'Shipped';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.cancelled: return 'Cancelled';
      case OrderStatus.failed: return 'Failed';
    }
  }
}

class PrintOrder {
  final String id;
  final String userId;
  final String printfulOrderId;
  final List<OrderItem> items;
  final ShippingAddress shippingAddress;
  final OrderStatus status;
  final DateTime orderDate;
  final DateTime? shippedDate;
  final DateTime? deliveredDate;
  final double subtotal;
  final double shipping;
  final double tax;
  final double totalAmount;
  final String? trackingNumber;
  final String? trackingUrl;
  final Map<String, dynamic> metadata;

  PrintOrder({
    required this.id,
    required this.userId,
    required this.printfulOrderId,
    required this.items,
    required this.shippingAddress,
    required this.status,
    required this.orderDate,
    this.shippedDate,
    this.deliveredDate,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.totalAmount,
    this.trackingNumber,
    this.trackingUrl,
    required this.metadata,
  });

  factory PrintOrder.fromPrintfulApi(Map<String, dynamic> json, String userId) {
    return PrintOrder(
      id: json['external_id'] ?? '',
      userId: userId,
      printfulOrderId: json['id'].toString(),
      items: (json['items'] as List)
          .map((item) => OrderItem.fromPrintfulApi(item))
          .toList(),
      shippingAddress: ShippingAddress.fromPrintfulApi(json['recipient']),
      status: OrderStatusExtension.fromPrintfulApi(json['status']),
      orderDate: DateTime.parse(json['created']),
      shippedDate: json['shipped'] != null ? DateTime.parse(json['shipped']) : null,
      deliveredDate: json['delivered'] != null ? DateTime.parse(json['delivered']) : null,
      subtotal: double.parse(json['retail_costs']['subtotal'].toString()),
      shipping: double.parse(json['retail_costs']['shipping'].toString()),
      tax: double.parse(json['retail_costs']['tax'].toString()),
      totalAmount: double.parse(json['retail_costs']['total'].toString()),
      trackingNumber: json['tracking_number'],
      trackingUrl: json['tracking_url'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  bool get canBeCancelled => status == OrderStatus.draft || status == OrderStatus.pending;
  bool get isComplete => status == OrderStatus.delivered;
  bool get hasTrackingInfo => trackingNumber != null && trackingNumber!.isNotEmpty;
}

class OrderItem {
  final String id;
  final int productId;
  final int variantId;
  final String productName;
  final String variantName;
  final int quantity;
  final double price;
  final String imageUrl;
  final String customImageId;
  final Map<String, dynamic> printSettings;

  OrderItem({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.price,
    required this.imageUrl,
    required this.customImageId,
    required this.printSettings,
  });

  factory OrderItem.fromPrintfulApi(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'].toString(),
      productId: json['product']['id'],
      variantId: json['variant']['id'],
      productName: json['product']['name'] ?? '',
      variantName: json['variant']['name'] ?? '',
      quantity: json['quantity'],
      price: double.parse(json['retail_price'].toString()),
      imageUrl: json['variant']['image'] ?? '',
      customImageId: json['files']?.first?['id']?.toString() ?? '',
      printSettings: Map<String, dynamic>.from(json['files']?.first ?? {}),
    );
  }

  Map<String, dynamic> toPrintfulApi() {
    return {
      'variant_id': variantId,
      'quantity': quantity,
      'retail_price': price,
      'files': [
        {
          'id': customImageId,
          ...printSettings,
        }
      ],
    };
  }

  double get totalPrice => price * quantity;
}

class ShippingAddress {
  final String fullName;
  final String? company;
  final String address1;
  final String? address2;
  final String city;
  final String stateCode;
  final String countryCode;
  final String zipCode;
  final String? phone;
  final String email;

  ShippingAddress({
    required this.fullName,
    this.company,
    required this.address1,
    this.address2,
    required this.city,
    required this.stateCode,
    required this.countryCode,
    required this.zipCode,
    this.phone,
    required this.email,
  });

  factory ShippingAddress.fromPrintfulApi(Map<String, dynamic> json) {
    return ShippingAddress(
      fullName: json['name'] ?? '',
      company: json['company'],
      address1: json['address1'] ?? '',
      address2: json['address2'],
      city: json['city'] ?? '',
      stateCode: json['state_code'] ?? '',
      countryCode: json['country_code'] ?? '',
      zipCode: json['zip'] ?? '',
      phone: json['phone'],
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': fullName,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state_code': stateCode,
      'country_code': countryCode,
      'zip': zipCode,
      'phone': phone,
      'email': email,
    };
  }

  String get formattedAddress {
    final parts = <String>[
      address1,
      if (address2 != null && address2!.isNotEmpty) address2!,
      '$city, $stateCode $zipCode',
      countryCode,
    ];
    return parts.join('\n');
  }
}