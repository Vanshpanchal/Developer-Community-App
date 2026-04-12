import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/avatar_provider.dart';
import 'shimmer_skeleton.dart';

/// Circular avatar preview widget that live-updates whenever AvatarProvider
/// changes. Uses CachedNetworkImage + shimmer placeholder.
class AvatarPreview extends StatelessWidget {
  final double size;
  final bool showShadow;
  final VoidCallback? onTap;

  const AvatarPreview({
    super.key,
    this.size = 120,
    this.showShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = context.select<AvatarProvider, String>((p) => p.avatarUrl);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: size,
            height: size,
            // Shimmer skeleton while loading
            placeholder: (_, __) => ShimmerSkeleton.circular(
              width: size,
              height: size,
            ),
            errorWidget: (_, __, ___) => _ErrorWidget(size: size),
          ),
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final double size;
  const _ErrorWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onErrorContainer,
        size: size * 0.4,
      ),
    );
  }
}
