import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerSkeleton.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const RoundedRectangleBorder(),
  });

  const ShimmerSkeleton.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: Colors.grey,
          shape: shapeBorder,
        ),
      ),
    );
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerSkeleton.circular(width: 40, height: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerSkeleton.rectangular(width: 120, height: 14),
                  const SizedBox(height: 4),
                  const ShimmerSkeleton.rectangular(width: 80, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerSkeleton.rectangular(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const ShimmerSkeleton.rectangular(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const ShimmerSkeleton.rectangular(width: 200, height: 16),
          const SizedBox(height: 16),
          const ShimmerSkeleton.rectangular(width: double.infinity, height: 200),
        ],
      ),
    );
  }
}

class DiscussionSkeleton extends StatelessWidget {
  const DiscussionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerSkeleton.circular(width: 40, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerSkeleton.rectangular(width: 120, height: 14),
                    const SizedBox(height: 4),
                    const ShimmerSkeleton.rectangular(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerSkeleton.rectangular(width: double.infinity, height: 18),
          const SizedBox(height: 8),
          const ShimmerSkeleton.rectangular(width: double.infinity, height: 14),
          const SizedBox(height: 4),
          const ShimmerSkeleton.rectangular(width: 200, height: 14),
          const SizedBox(height: 12),
          Row(
            children: [
              const ShimmerSkeleton.rectangular(width: 60, height: 24),
              const SizedBox(width: 8),
              const ShimmerSkeleton.rectangular(width: 60, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}
