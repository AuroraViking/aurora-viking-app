import 'package:cloud_firestore/cloud_firestore.dart';

class AuroraComment {
  final String id;
  final String sightingId;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final int likes;
  final int replies;
  final String? parentCommentId;

  AuroraComment({
    required this.id,
    required this.sightingId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.replies,
    this.parentCommentId,
  });

  factory AuroraComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuroraComment(
      id: doc.id,
      sightingId: data['sightingId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      content: data['content'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likes: data['likes'] as int? ?? 0,
      replies: data['replies'] as int? ?? 0,
      parentCommentId: data['parentCommentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sightingId': sightingId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'replies': replies,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  AuroraComment copyWith({
    String? id,
    String? sightingId,
    String? userId,
    String? userName,
    String? content,
    DateTime? timestamp,
    int? likes,
    int? replies,
    String? parentCommentId,
  }) {
    return AuroraComment(
      id: id ?? this.id,
      sightingId: sightingId ?? this.sightingId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
} 