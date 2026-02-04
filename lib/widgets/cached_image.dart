import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Optimized cached network image widget
/// Automatically handles caching, loading states, and errors
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 32,
            ),
          ),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Optimized cached image provider for CircleAvatar and other ImageProvider widgets
class CachedImageProvider extends CachedNetworkImageProvider {
  CachedImageProvider(
    super.url, {
    super.scale,
    super.headers,
    super.cacheManager,
    super.maxHeight = 500,
    super.maxWidth = 500,
  });

  /// Create from URL with default caching settings
  factory CachedImageProvider.fromUrl(String url) {
    return CachedImageProvider(
      url,
      maxHeight: 500,
      maxWidth: 500,
    );
  }
}

/// Helper function to create a cached avatar
Widget cachedAvatar({
  required String imageUrl,
  required double radius,
  Widget? placeholder,
  Widget? errorWidget,
  Color? backgroundColor,
}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage:
        imageUrl.isNotEmpty ? CachedImageProvider.fromUrl(imageUrl) : null,
    child: imageUrl.isEmpty ? (errorWidget ?? const Icon(Icons.person)) : null,
  );
}
