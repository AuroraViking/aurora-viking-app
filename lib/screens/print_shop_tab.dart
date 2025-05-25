// lib/screens/print_shop_tab.dart
import 'package:flutter/material.dart';

class PrintShopTab extends StatefulWidget {
  const PrintShopTab({super.key});

  @override
  State<PrintShopTab> createState() => _PrintShopTabState();
}

class _PrintShopTabState extends State<PrintShopTab> {
  final List<PrintProduct> _featuredProducts = [
    PrintProduct(
      id: 1,
      name: 'Canvas Print',
      description: 'High-quality canvas prints of your aurora photos',
      price: 29.99,
      imageUrl: 'https://picsum.photos/300/300?random=10',
      category: 'Prints',
    ),
    PrintProduct(
      id: 2,
      name: 'Aurora T-Shirt',
      description: 'Comfortable t-shirt with your aurora photo',
      price: 24.99,
      imageUrl: 'https://picsum.photos/300/300?random=11',
      category: 'Apparel',
    ),
    PrintProduct(
      id: 3,
      name: 'Photo Book',
      description: 'Beautiful hardcover book with your aurora memories',
      price: 39.99,
      imageUrl: 'https://picsum.photos/300/300?random=12',
      category: 'Books',
    ),
    PrintProduct(
      id: 4,
      name: 'Phone Case',
      description: 'Protective case featuring your favorite aurora shot',
      price: 19.99,
      imageUrl: 'https://picsum.photos/300/300?random=13',
      category: 'Accessories',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildComingSoonBanner(),
            Expanded(
              child: _buildProductGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Print Shop',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
              shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: () {
              // TODO: Open shopping cart
            },
            icon: Stack(
              children: [
                Icon(Icons.shopping_cart_outlined, color: Colors.tealAccent),
                // Cart badge (when items are added)
                // Positioned(
                //   right: 0,
                //   top: 0,
                //   child: Container(
                //     padding: EdgeInsets.all(2),
                //     decoration: BoxDecoration(
                //       color: Colors.red,
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //     constraints: BoxConstraints(
                //       minWidth: 16,
                //       minHeight: 16,
                //     ),
                //     child: Text('2', style: TextStyle(fontSize: 10)),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.construction, color: Colors.amber, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Print Shop Coming Soon!',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'We\'re working on bringing you beautiful prints of your aurora photos. Stay tuned!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _featuredProducts.length,
        itemBuilder: (context, index) {
          return _buildProductCard(_featuredProducts[index]);
        },
      ),
    );
  }

  Widget _buildProductCard(PrintProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.tealAccent,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.withOpacity(0.2),
                          child: Icon(
                            Icons.image,
                            color: Colors.white54,
                            size: 32,
                          ),
                        );
                      },
                    ),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        product.description,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.category,
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
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

          // Coming soon overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple product model for the preview
class PrintProduct {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;

  PrintProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
  });
}