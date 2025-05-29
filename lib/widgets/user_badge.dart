import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../screens/tour_auth_screen.dart';
import '../screens/profile_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBadge extends StatelessWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseService().auth.authStateChanges(),
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.hasData;
        final displayName = FirebaseService().userDisplayName;
        final userType = isAuthenticated ? 'aurora_user' : 'not_signed_in';

        return GestureDetector(
          onTap: () {
            if (isAuthenticated) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileSettingsScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TourAuthScreen(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getUserTypeColor(userType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getUserTypeColor(userType).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getUserTypeIcon(userType),
                  color: _getUserTypeColor(userType),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isAuthenticated ? '$displayName • ${_getUserTypeLabel(userType)}' : 'Sign In',
                  style: TextStyle(
                    color: _getUserTypeColor(userType),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getUserTypeColor(String userType) {
    switch (userType) {
      case 'tour_participant':
        return Colors.tealAccent;
      case 'aurora_user':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'tour_participant':
        return 'Tour Participant';
      case 'aurora_user':
        return 'Aurora App User';
      default:
        return 'Sign In';
    }
  }

  IconData _getUserTypeIcon(String userType) {
    switch (userType) {
      case 'tour_participant':
        return Icons.card_travel;
      case 'aurora_user':
        return Icons.person;
      default:
        return Icons.login;
    }
  }
} 