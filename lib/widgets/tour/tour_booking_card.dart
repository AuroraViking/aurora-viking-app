import 'package:flutter/material.dart';
import '../../models/tour.dart';
import '../../services/bokun_service.dart';

class TourBookingCard extends StatefulWidget {
  final Tour tour;

  const TourBookingCard({
    super.key,
    required this.tour,
  });

  @override
  State<TourBookingCard> createState() => _TourBookingCardState();
}

class _TourBookingCardState extends State<TourBookingCard> {
  final BokunService _bokunService = BokunService();
  Map<String, dynamic>? _bookingDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final details = await _bokunService.getTourDetails(widget.tour.bookingReference);
      setState(() {
        _bookingDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                Expanded(
                  child: Text(
                    'Booking Details',
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

          const SizedBox(height: 16),

          // Booking Details
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoSection(
                              'Tour Information',
                              [
                                _buildInfoRow('Tour Name', widget.tour.name),
                                _buildInfoRow('Location', widget.tour.location),
                                _buildInfoRow(
                                  'Date',
                                  '${widget.tour.date.day}/${widget.tour.date.month}/${widget.tour.date.year}',
                                ),
                                _buildInfoRow(
                                  'Booking Reference',
                                  widget.tour.bookingReference,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoSection(
                              'Booking Details',
                              [
                                _buildInfoRow(
                                  'Status',
                                  _bookingDetails?['status'] ?? 'N/A',
                                  valueColor: Colors.tealAccent,
                                ),
                                _buildInfoRow(
                                  'Pickup Location',
                                  _bookingDetails?['pickupLocation'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Pickup Time',
                                  _bookingDetails?['pickupTime'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Duration',
                                  _bookingDetails?['duration'] ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  'Group Size',
                                  _bookingDetails?['groupSize'] ?? 'N/A',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoSection(
                              'Payment Information',
                              [
                                _buildInfoRow(
                                  'Price',
                                  _bookingDetails?['price'] ?? 'N/A',
                                  valueColor: Colors.tealAccent,
                                ),
                                _buildInfoRow(
                                  'Currency',
                                  _bookingDetails?['currency'] ?? 'N/A',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildInfoSection(
                              'Cancellation Policy',
                              [
                                _buildInfoRow(
                                  'Policy',
                                  _bookingDetails?['cancellationPolicy'] ?? 'N/A',
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.tealAccent.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 