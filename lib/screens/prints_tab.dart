import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/printful_service.dart';
import '../services/firebase_service.dart';
import '../models/print_product.dart';
import '../models/user_aurora_photo.dart';

class PrintsTab extends StatefulWidget {
  final UserAuroraPhoto? preSelectedPhoto;

  const PrintsTab({super.key, this.preSelectedPhoto});

  @override
  State<PrintsTab> createState() => _PrintsTabState();
}

class _PrintsTabState extends State<PrintsTab> with TickerProviderStateMixin {
  final PrintfulService _printfulService = PrintfulService();
  final FirebaseService _firebaseService = FirebaseService();

  List<PrintProduct> _products = [];
  final List<CartItem> _cartItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  late TabController _tabController;

  final Map<String, IconData> _categories = {
    'all': Icons.grid_view,
    'poster': Icons.image,
    'canvas': Icons.brush,
    'mug': Icons.coffee,
    'phone-case': Icons.phone_android,
    't-shirt': Icons.checkroom,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadProducts();

    // Show photo options if pre-selected
    if (widget.preSelectedPhoto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPhotoOptions();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _printfulService.getAuroraProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PrintProduct> get _filteredProducts {
    if (_selectedCategory == 'all') {
      return _products;
    }
    return _products.where((product) => product.type == _selectedCategory).toList();
  }

  void _addToCart(PrintProduct product, ProductVariant variant) {
    final existingIndex = _cartItems.indexWhere(
          (item) => item.variantId == variant.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
          quantity: _cartItems[existingIndex].quantity + 1,
        );
      } else {
        _cartItems.add(CartItem(
          variantId: variant.id,
          productName: widget.preSelectedPhoto != null
              ? '${product.name} - ${widget.preSelectedPhoto!.locationName}'
              : product.name,
          variantName: variant.name,
          price: variant.price,
          quantity: 1,
          customPhotoUrl: widget.preSelectedPhoto?.photoUrl,
        ));
      }
    });

    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        backgroundColor: const Color(0xFF00D4AA),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: Colors.white,
          onPressed: _showCart,
        ),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: _buildCartSheet(),
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    if (widget.preSelectedPhoto == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: _buildPhotoOptionsSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Pre-selected photo banner
                  if (widget.preSelectedPhoto != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.preSelectedPhoto!.photoUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image, color: Colors.white54),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Photo',
                                  style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.preSelectedPhoto!.locationName,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                Text(
                                  '${widget.preSelectedPhoto!.intensityDescription} Aurora',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _showPhotoOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Print This'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Main header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aurora Print Shop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.preSelectedPhoto != null
                                  ? 'Create beautiful prints of your aurora photo'
                                  : 'Transform your aurora memories into beautiful prints',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cart icon
                      Stack(
                        children: [
                          IconButton(
                            onPressed: _cartItems.isEmpty ? null : _showCart,
                            icon: Icon(
                              Icons.shopping_cart_outlined,
                              color: _cartItems.isEmpty
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF00D4AA),
                              size: 28,
                            ),
                          ),
                          if (_cartItems.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_cartItems.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Category tabs
            SizedBox(
              height: 50,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFF00D4AA),
                labelColor: const Color(0xFF00D4AA),
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                onTap: (index) {
                  setState(() {
                    _selectedCategory = _categories.keys.elementAt(index);
                  });
                },
                tabs: _categories.entries.map((entry) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(entry.value, size: 20),
                        const SizedBox(width: 8),
                        Text(entry.key.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Products grid
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D4AA)),
              )
                  : _filteredProducts.isEmpty
                  ? _buildEmptyState()
                  : _buildProductsGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadProducts,
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF00D4AA))),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: const Color(0xFF00D4AA),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(PrintProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.grey[800],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.images.isNotEmpty
                    ? Image.network(
                  product.images.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, color: Colors.white54, size: 48);
                  },
                )
                    : const Icon(Icons.image, color: Colors.white54, size: 48),
              ),
            ),
          ),

          // Product info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        product.variants.isNotEmpty
                            ? 'From \$${product.variants.first.price.toStringAsFixed(2)}'
                            : 'Price not available',
                        style: const TextStyle(
                          color: Color(0xFF00D4AA),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showVariantSelector(product),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVariantSelector(PrintProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1F2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Variants
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: product.variants.length,
                    itemBuilder: (context, index) {
                      final variant = product.variants[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: const Color(0xFF00D4AA).withOpacity(0.3)),
                          ),
                          tileColor: const Color(0xFF0A0F1C),
                          title: Text(variant.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Size: ${variant.size}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6)),
                          ),
                          trailing: Text(
                            '\$${variant.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00D4AA),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            _addToCart(product, variant);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Shopping Cart',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_cartItems.length} items',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                ),
              ],
            ),
          ),

          // Cart items
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
              child: Text('Your cart is empty', style: TextStyle(color: Colors.white70)),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      // Custom photo preview if available
                      if (item.customPhotoUrl != null) ...[
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.customPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image, color: Colors.white54),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.variantName,
                              style: TextStyle(color: Colors.white.withOpacity(0.6)),
                            ),
                            Text(
                              '\$${item.price.toStringAsFixed(2)} each',
                              style: const TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Checkout button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _cartItems.isEmpty ? null : () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checkout coming soon!'),
                      backgroundColor: Color(0xFF00D4AA),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoOptionsSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.preSelectedPhoto!.photoUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Print Your Aurora Photo',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.preSelectedPhoto!.locationName,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Product options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(product.description, style: const TextStyle(color: Colors.white70)),
                    trailing: Text(
                      product.variants.isNotEmpty ? 'From \$${product.variants.first.price.toStringAsFixed(2)}' : 'N/A',
                      style: const TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _showVariantSelector(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Simple CartItem class
class CartItem {
  final int variantId;
  final String productName;
  final String variantName;
  final double price;
  final int quantity;
  final String? customPhotoUrl;

  CartItem({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.price,
    required this.quantity,
    this.customPhotoUrl,
  });

  CartItem copyWith({
    int? variantId,
    String? productName,
    String? variantName,
    double? price,
    int? quantity,
    String? customPhotoUrl,
  }) {
    return CartItem(
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      variantName: variantName ?? this.variantName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      customPhotoUrl: customPhotoUrl ?? this.customPhotoUrl,
    );
  }
}