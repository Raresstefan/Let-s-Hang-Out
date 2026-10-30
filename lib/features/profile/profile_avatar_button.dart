import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/user_repository.dart';
import 'profile_screen.dart';

/// A circular avatar button for app-bar `actions` that opens the (editable)
/// Profile. Profile moved off the bottom nav once Circles took its slot, so
/// every main screen surfaces this in the top-right.
class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({super.key});

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    try {
      final profile = await context.read<UserRepository>().fetchProfile(uid);
      if (mounted) setState(() => _photo = profile?.avatarUrl);
    } catch (error) {
      debugPrint('Could not load profile avatar: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final photo = _photo ?? auth.photoUrl;
    final name = auth.displayName ?? '';
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initial = (name.trim().isEmpty ? '?' : name.trim()[0]).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          if (mounted) await _loadPhoto();
        },
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasPhoto ? null : AppTheme.brandGradient,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? CoverImage(source: photo)
              : Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
