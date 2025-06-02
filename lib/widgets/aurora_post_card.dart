import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../models/aurora_sighting.dart';
import '../models/aurora_comment.dart';
import '../services/firebase_service.dart';

class AuroraPostCard extends StatefulWidget {
  AuroraSighting sighting;
  final VoidCallback? onTap;
  final Function(String)? onComment;
  final Function(String)? onLike;
  final Function(String)? onShare;
  final Function(String)? onViewProfile;
  final Function(GeoPoint)? onViewLocation;

  AuroraPostCard({
    super.key,
    required this.sighting,
    this.onTap,
    this.onComment,
    this.onLike,
    this.onShare,
    this.onViewProfile,
    this.onViewLocation,
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

  @override
  void initState() {
    super.initState();
    _loadComments();
    _checkIfLiked();
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
      print('Error loading comments: $e');
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

  Future<void> _handleLike() async {
    try {
      final result = await _firebaseService.confirmAuroraSighting(widget.sighting.id);
      
      setState(() {
        _isLiked = result['isLiked'];
        widget.sighting = widget.sighting.copyWith(
          confirmations: result['confirmations'],
          confirmedByUsers: result['isLiked'] 
            ? [...widget.sighting.confirmedByUsers, _firebaseService.currentUser!.uid]
            : widget.sighting.confirmedByUsers.where((id) => id != _firebaseService.currentUser!.uid).toList(),
          isVerified: result['confirmations'] >= 3,
        );
      });

      if (widget.onLike != null) {
        widget.onLike!(widget.sighting.id);
      }
    } catch (e) {
      print('Error handling like: $e');
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
          if (widget.sighting.photoUrls.isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: widget.sighting.photoUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    widget.sighting.photoUrls[index],
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),

          // Description
          if (widget.sighting.description != null && widget.sighting.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.sighting.description!,
                style: const TextStyle(color: Colors.white),
              ),
            ),

          // Weather conditions
          if (widget.sighting.weather.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.thermostat, color: Colors.tealAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'BzH: ${widget.sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT • Kp: ${widget.sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                    setState(() => _showComments = !_showComments);
                    if (_showComments) _loadComments();
                  },
                  icon: const Icon(Icons.comment_outlined, color: Colors.white70),
                  label: Text(
                    '${_comments.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _shareSighting,
                  icon: const Icon(Icons.share_outlined, color: Colors.white70),
                  label: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white70),
                  ),
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
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[300],
          child: Text(
            widget.sighting.userName[0].toUpperCase(),
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.sighting.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.sighting.timeAgo,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'report':
                // TODO: Implement report functionality
                break;
              case 'profile':
                if (widget.onViewProfile != null) {
                  widget.onViewProfile!(widget.sighting.userId);
                }
                break;
              case 'location':
                if (widget.onViewLocation != null) {
                  widget.onViewLocation!(widget.sighting.location);
                }
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Report to Admin'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text('Poster\'s Profile'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'location',
              child: Row(
                children: [
                  Icon(Icons.location_on),
                  SizedBox(width: 8),
                  Text('Location on Map'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
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