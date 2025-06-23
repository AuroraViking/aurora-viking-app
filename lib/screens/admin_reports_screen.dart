import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aurora_sighting.dart';
import '../widgets/aurora_post_card.dart';
import '../services/firebase_service.dart';

class AdminReportsScreen extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  Future<AuroraSighting?> _fetchSighting(String sightingId) async {
    print('Fetching sighting: $sightingId');
    final doc = await FirebaseFirestore.instance.collection('aurora_sightings').doc(sightingId).get();
    if (!doc.exists) {
      print('Sighting not found: $sightingId');
      return null;
    }
    print('Sighting found: $sightingId');
    return AuroraSighting.fromFirestore(doc);
  }

  Future<void> _showReportActions(BuildContext context, Map<String, dynamic> data, String reportId) async {
    print('_showReportActions called with data: $data');
    final sightingId = data['sightingId'];
    final userId = data['userId'];
    
    if (sightingId == null) {
      print('Error: sightingId is null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No sighting ID found in report')),
      );
      return;
    }
    
    AuroraSighting? sighting;
    bool isBlocked = false;
    
    try {
      // Fetch sighting and block status in parallel
      await Future.wait([
        _fetchSighting(sightingId).then((s) => sighting = s),
        FirebaseFirestore.instance.collection('blocked_users').doc(userId).get().then((doc) => isBlocked = doc.exists),
      ]);
      
      print('Fetched sighting: ${sighting != null ? 'found' : 'not found'}');
      print('User blocked status: $isBlocked');
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Report Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sighting ID: $sightingId'),
                  Text('User ID: $userId'),
                  Text('Reason: ${data['reason'] ?? 'N/A'}'),
                  Text('Status: ${data['status'] ?? 'pending'}'),
                  Text('Timestamp: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : 'N/A'}'),
                  const SizedBox(height: 16),
                  if (sighting != null) ...[
                    // Sighting header
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.tealAccent,
                          child: Text(
                            sighting!.userName[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.black,
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
                                sighting!.userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                sighting!.timeAgo,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getIntensityColor(sighting!.intensity).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Intensity ${sighting!.intensity}',
                            style: TextStyle(
                              color: _getIntensityColor(sighting!.intensity),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Photos
                    if (sighting!.photoUrls.isNotEmpty) ...[
                      Container(
                        height: 200,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            sighting!.photoUrls.first, // Show first photo only
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: Icon(Icons.error, color: Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                      if (sighting!.photoUrls.length > 1)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '${sighting!.photoUrls.length} photos total',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Description
                    if (sighting!.description != null && sighting!.description!.isNotEmpty) ...[
                      Text(
                        'Description:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sighting!.description!,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sighting!.locationName,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    
                    // Weather conditions
                    if (sighting!.weather.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.cloud, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'BzH: ${sighting!.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT • Kp: ${sighting!.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ] else
                    const Text('Sighting not found or already deleted.'),
                ],
              ),
            ),
            actions: [
              if (sighting != null)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Sighting'),
                        content: Text('Are you sure you want to delete this sighting?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('aurora_sightings').doc(sightingId).delete();
                      setState(() => sighting = null);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sighting deleted.')),
                      );
                    }
                  },
                  child: Text('Delete Sighting', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () async {
                  if (isBlocked) {
                    // Unblock
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Unblock User'),
                        content: Text('This user is currently blocked. Unblock them?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Unblock')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('blocked_users').doc(userId).delete();
                      setState(() => isBlocked = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User unblocked.')),
                      );
                    }
                  } else {
                    // Block
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Block User'),
                        content: Text('Are you sure you want to block this user?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Block')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('blocked_users').doc(userId).set({
                        'blocked': true, 
                        'timestamp': FieldValue.serverTimestamp(),
                        'blockedBy': FirebaseAuth.instance.currentUser?.uid,
                        'reason': 'Reported content'
                      });
                      setState(() => isBlocked = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User blocked.')),
                      );
                    }
                  }
                },
                child: Text(isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: Colors.orange)),
              ),
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Report'),
                      content: Text('Are you sure you want to delete this report?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
                    Navigator.pop(context); // Close the dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Report deleted.')),
                    );
                  }
                },
                child: Text('Delete Report', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error in _showReportActions: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report details: $e')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block),
            onPressed: () => _showBlockedUsersDialog(context),
            tooltip: 'Manage Blocked Users',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }
          final reports = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Sighting: ${data['sightingId'] ?? 'N/A'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: ${data['userId'] ?? 'N/A'}'),
                      Text('Reason: ${data['reason'] ?? 'N/A'}'),
                      Text('Status: ${data['status'] ?? 'pending'}'),
                      Text('Timestamp: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : 'N/A'}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      await report.reference.update({'status': value});
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pending',
                        child: Text('Mark as Pending'),
                      ),
                      const PopupMenuItem(
                        value: 'resolved',
                        child: Text('Mark as Resolved'),
                      ),
                    ],
                    child: Icon(Icons.more_vert),
                  ),
                  onTap: () {
                    print('Report tapped: ${report.id}');
                    _showReportActions(context, data, report.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showBlockedUsersDialog(BuildContext context) async {
    try {
      // Get all blocked users
      final blockedSnapshot = await FirebaseFirestore.instance.collection('blocked_users').get();
      
      if (blockedSnapshot.docs.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Blocked Users'),
            content: Text('No users are currently blocked.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      // Get user details for each blocked user
      List<Map<String, dynamic>> blockedUsers = [];
      for (final doc in blockedSnapshot.docs) {
        final userId = doc.id;
        final blockData = doc.data();
        
        try {
          // Get user profile to get username
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final userData = userDoc.data();
          final userName = userData?['displayName'] ?? userData?['email']?.split('@')[0] ?? 'Unknown User';
          
          blockedUsers.add({
            'userId': userId,
            'userName': userName,
            'email': userData?['email'] ?? 'No email',
            'blockedAt': blockData['timestamp'],
            'blockedBy': blockData['blockedBy'],
            'reason': blockData['reason'] ?? 'No reason provided',
          });
        } catch (e) {
          // If user profile not found, still show the blocked user
          blockedUsers.add({
            'userId': userId,
            'userName': 'Unknown User',
            'email': 'No email',
            'blockedAt': blockData['timestamp'],
            'blockedBy': blockData['blockedBy'],
            'reason': blockData['reason'] ?? 'No reason provided',
          });
        }
      }

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Blocked Users (${blockedUsers.length})'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: blockedUsers.length,
                itemBuilder: (context, index) {
                  final user = blockedUsers[index];
                  final blockedAt = user['blockedAt'] as Timestamp?;
                  final blockedDate = blockedAt != null 
                    ? blockedAt.toDate().toString().substring(0, 19) 
                    : 'Unknown date';
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(user['userName']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${user['email']}'),
                          Text('Blocked: $blockedDate'),
                          Text('Reason: ${user['reason']}'),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Unblock User'),
                              content: Text('Are you sure you want to unblock ${user['userName']}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Unblock')),
                              ],
                            ),
                          );
                          
                          if (confirm == true) {
                            await FirebaseFirestore.instance.collection('blocked_users').doc(user['userId']).delete();
                            // Clear block cache to ensure user can post immediately
                            await _firebaseService.clearBlockCache(user['userId']);
                            setState(() {
                              blockedUsers.removeAt(index);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${user['userName']} has been unblocked.')),
                            );
                          }
                        },
                        child: Text('Unblock', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error loading blocked users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading blocked users: $e')),
      );
    }
  }
} 