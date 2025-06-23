import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../models/aurora_sighting.dart';
import '../models/aurora_comment.dart';
import '../services/firebase_service.dart';
import 'aurora_photo_viewer.dart';

class AuroraPostCard extends StatefulWidget {
  AuroraSighting sighting;
  final Function(String) onLike;
  final Function(String) onViewProfile;
  final Function(GeoPoint) onViewLocation;
  final VoidCallback? onTap;
  final Function(String)? onComment;
  final Function(String)? onShare;

  AuroraPostCard({
    super.key,
    required this.sighting,
    required this.onLike,
    required this.onViewProfile,
    required this.onViewLocation,
    this.onTap,
    this.onComment,
    this.onShare,
  });

  @override
  State<AuroraPostCard> createState() => _AuroraPostCardState();
}

class _AuroraPostCardState extends State<AuroraPostCard> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLiked = false;
  bool _showComments = false;
  List<AuroraComment> _comments = [];
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();

  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _checkIfLiked();
    _fetchProfilePicture();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments = await _firebaseService.getCommentsForSighting(widget.sighting.id);
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _checkIfLiked() async {
    final userId = _firebaseService.currentUser?.uid;
    if (userId != null) {
      setState(() {
        _isLiked = widget.sighting.confirmedByUsers.contains(userId);
      });
    }
  }

  Future<void> _fetchProfilePicture() async {
    try {
      final userDoc = await _firebaseService.firestore.collection('users').doc(widget.sighting.userId).get();
      final url = userDoc.data()?['profilePictureUrl'] as String?;
      if (mounted) {
        setState(() {
          _profilePictureUrl = url;
        });
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
    }
  }

  Future<void> _handleLike() async {
    try {
      final result = await _firebaseService.confirmAuroraSighting(widget.sighting.id);
      
      setState(() {
        _isLiked = result['isLiked'];
        widget.sighting = widget.sighting.copyWith(
          confirmations: result['confirmations'],
          confirmedByUsers: result['verifications'],
          isVerified: result['confirmations'] >= 3,
        );
      });
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Revert the like state if there was an error
      setState(() {
        _isLiked = !_isLiked;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await _firebaseService.addComment(
        sightingId: widget.sighting.id,
        content: _commentController.text.trim(),
      );
      _commentController.clear();
      _loadComments();
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> _shareSighting() async {
    final shareText = '''
${widget.sighting.intensityDescription} Aurora spotted in ${widget.sighting.locationName}!

Intensity: ${widget.sighting.intensity}
Time: ${widget.sighting.timeAgo}
${widget.sighting.description != null ? '\nDescription: ${widget.sighting.description}' : ''}

Shared via Aurora Viking App
''';

    await Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          // Photos
          widget.sighting.photoUrls.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AuroraSightingPhotoViewer(
                        photoUrls: widget.sighting.photoUrls,
                        locationName: widget.sighting.locationName,
                        userName: widget.sighting.userName,
                        timeAgo: widget.sighting.timeAgo,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: 300,
                  child: PageView.builder(
                    itemCount: widget.sighting.photoUrls.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Image.network(
                            widget.sighting.photoUrls[index],
                            fit: BoxFit.cover,
                          ),
                          // Show photo counter if multiple photos
                          if (widget.sighting.photoUrls.length > 1)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${index + 1}/${widget.sighting.photoUrls.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          // Fullscreen indicator
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )
            : Container(
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.tealAccent),
                      SizedBox(width: 8),
                      Text(
                        'Location-only post',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

          // Description
          if (widget.sighting.description != null && widget.sighting.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.sighting.description!,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 5,
              ),
            ),

          // Weather conditions
          if (widget.sighting.weather.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.cloud, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BzH: ${widget.sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT • Kp: ${widget.sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Intensity rating
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intensity: ${widget.sighting.intensity}',
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Location info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.sighting.locationName} (${widget.sighting.location.latitude.toStringAsFixed(2)}, ${widget.sighting.location.longitude.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _handleLike,
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white70,
                  ),
                  label: Text(
                    '${widget.sighting.confirmations}',
                    style: TextStyle(
                      color: _isLiked ? Colors.red : Colors.white70,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showComments = !_showComments;
                    });
                  },
                  icon: Icon(
                    Icons.comment,
                    color: _showComments ? Colors.tealAccent : Colors.white70,
                  ),
                  label: Text(
                    '${widget.sighting.commentCount}',
                    style: TextStyle(
                      color: _showComments ? Colors.tealAccent : Colors.white70,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _shareSighting,
                  icon: const Icon(Icons.share, color: Colors.white70),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),

          // Comments section
          if (_showComments) ...[
            const Divider(color: Colors.white24),
            if (_isLoadingComments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                ),
              )
            else if (_comments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.tealAccent,
                      child: Icon(Icons.person, color: Colors.black, size: 16),
                    ),
                    title: Text(
                      comment.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.content,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          comment.timeAgo,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Add comment
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.tealAccent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.tealAccent),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => widget.onViewProfile.call(widget.sighting.userId),
            child: CircleAvatar(
              backgroundColor: Colors.tealAccent,
              backgroundImage: _profilePictureUrl != null ? NetworkImage(_profilePictureUrl!) : null,
              child: _profilePictureUrl == null
                  ? Text(
                      widget.sighting.userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sighting.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  widget.sighting.timeAgo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _showReportDialog();
                  break;
                case 'profile':
                  widget.onViewProfile.call(widget.sighting.userId);
                  break;
                case 'location':
                  widget.onViewLocation.call(widget.sighting.location);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report to Admin'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.tealAccent),
                    SizedBox(width: 8),
                    Text('Poster\'s Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'location',
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.tealAccent),
                    SizedBox(width: 8),
                    Text('Location on Map'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Sighting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Inappropriate Content'),
              onTap: () => _submitReport('Inappropriate Content'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(String reason) {
    Navigator.pop(context); // Close the dialog
    _firebaseService.firestore.collection('reports').add({
      'sightingId': widget.sighting.id,
      'userId': _firebaseService.currentUser?.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1: return Colors.blue[300]!;
      case 2: return Colors.green[400]!;
      case 3: return Colors.tealAccent;
      case 4: return Colors.orange[400]!;
      case 5: return Colors.amber;
      default: return Colors.grey;
    }
  }
}