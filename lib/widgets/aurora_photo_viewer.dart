import 'package:flutter/material.dart';
import '../models/user_aurora_photo.dart';
import '../services/firebase_service.dart';
import '../services/user_photos_service.dart';

class AuroraPhotoViewer extends StatefulWidget {
  final UserAuroraPhoto photo;
  final VoidCallback? onDelete;

  const AuroraPhotoViewer({
    super.key,
    required this.photo,
    this.onDelete,
  });

  @override
  State<AuroraPhotoViewer> createState() => _AuroraPhotoViewerState();
}

class _AuroraPhotoViewerState extends State<AuroraPhotoViewer> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _showComments = false;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadPhotoStats();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoStats() async {
    try {
      final doc = await _firebaseService.firestore
          .collection('aurora_sightings')
          .doc(widget.photo.sightingId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _likeCount = data['confirmations'] ?? 0;
          _commentCount = data['commentCount'] ?? 0;
          _isLiked = (data['confirmedByUsers'] as List<dynamic>?)?.contains(_firebaseService.currentUser?.uid) ?? false;
        });
      }
    } catch (e) {
      print('Error loading photo stats: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final commentsSnapshot = await _firebaseService.firestore
          .collection('aurora_sightings')
          .doc(widget.photo.sightingId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _comments = commentsSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _handleLike() async {
    try {
      final result = await _firebaseService.confirmAuroraSighting(widget.photo.sightingId);
      setState(() {
        _isLiked = result['isLiked'];
        _likeCount = result['confirmations'];
      });
    } catch (e) {
      print('Error handling like: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await _firebaseService.addComment(
        sightingId: widget.photo.sightingId,
        content: _commentController.text.trim(),
      );
      _commentController.clear();
      await _loadComments();
      await _loadPhotoStats();
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> _deletePhoto() async {
    try {
      // Delete the user photo (handles storage and Firestore)
      await UserPhotosService.deletePhoto(widget.photo.id);
      // Optionally, also delete the associated sighting
      await _firebaseService.firestore
          .collection('aurora_sightings')
          .doc(widget.photo.sightingId)
          .delete();

      if (widget.onDelete != null) {
        widget.onDelete!();
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error deleting photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete photo. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Photo'),
                  content: const Text('Are you sure you want to delete this photo? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePhoto();
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.photo.photoUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Photo Info
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.tealAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.photo.locationName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.photo.formattedDateTime,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Intensity: ${widget.photo.intensityDescription}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
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
                    '$_likeCount',
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
                    '$_commentCount',
                    style: TextStyle(
                      color: _showComments ? Colors.tealAccent : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Comments Section
          if (_showComments) ...[
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.tealAccent,
                      child: Icon(Icons.person, color: Colors.black, size: 16),
                    ),
                    title: Text(
                      comment['userName'] ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      comment['content'] ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
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
} 