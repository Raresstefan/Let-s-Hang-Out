import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';
import 'profile_screen.dart';

/// A circular avatar button for app-bar `actions` that opens the (editable)
/// Profile. Profile moved off the bottom nav once Circles took its slot, so
/// every main screen surfaces this in the top-right.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final photo = auth.photoUrl;
    final name = auth.displayName ?? '';
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initial = (name.trim().isEmpty ? '?' : name.trim()[0]).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasPhoto ? null : AppTheme.brandGradient,
            image: hasPhoto
                ? DecorationImage(
                    image: NetworkImage(photo), fit: BoxFit.cover)
                : null,
          ),
          child: hasPhoto
              ? null
              : Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
        ),
      ),
    );
  }
}
