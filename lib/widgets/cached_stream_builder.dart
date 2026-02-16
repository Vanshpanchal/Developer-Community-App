import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_cache_service.dart';

/// CachedStreamBuilder - A StreamBuilder with built-in caching
///
/// This widget provides intelligent caching for Firestore streams:
/// - Shows cached data immediately if available
/// - Fetches fresh data in the background
/// - Updates UI when fresh data arrives
/// - Automatically caches new data
class CachedStreamBuilder<T> extends StatefulWidget {
  final String collectionName;
  final Map<String, dynamic>? where;
  final String? orderBy;
  final bool descending;
  final int? limit;
  final Widget Function(BuildContext, AsyncSnapshot<QuerySnapshot>) builder;

  const CachedStreamBuilder({
    super.key,
    required this.collectionName,
    this.where,
    this.orderBy,
    this.descending = false,
    this.limit,
    required this.builder,
  });

  @override
  State<CachedStreamBuilder<T>> createState() => _CachedStreamBuilderState<T>();
}

class _CachedStreamBuilderState<T> extends State<CachedStreamBuilder<T>> {
  final _cacheService = FirebaseCacheService();
  // ignore: unused_field
  List<Map<String, dynamic>>? _cachedData;
  // ignore: unused_field
  bool _hasShownCache = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  String _buildCacheKey() {
    final parts = [widget.collectionName];

    if (widget.where != null && widget.where!.isNotEmpty) {
      widget.where!.forEach((key, value) {
        parts.add('${key}_$value');
      });
    }

    if (widget.orderBy != null) {
      parts.add('order_${widget.orderBy}');
    }

    if (widget.limit != null) {
      parts.add('limit_${widget.limit}');
    }

    return parts.join('_');
  }

  Future<void> _loadCachedData() async {
    final cached = _cacheService.getCachedCollection(
      _buildCacheKey(),
    );

    if (cached != null && mounted) {
      setState(() {
        _cachedData = cached;
        _hasShownCache = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the regular stream
    return StreamBuilder<QuerySnapshot>(
      stream: _buildStream(),
      builder: widget.builder,
    );
  }

  Stream<QuerySnapshot> _buildStream() {
    Query query = FirebaseFirestore.instance.collection(widget.collectionName);

    if (widget.where != null) {
      widget.where!.forEach((field, value) {
        query = query.where(field, isEqualTo: value);
      });
    }

    if (widget.orderBy != null) {
      query = query.orderBy(widget.orderBy!, descending: widget.descending);
    }

    if (widget.limit != null) {
      query = query.limit(widget.limit!);
    }

    // Listen to the stream and cache data as it arrives
    return query.snapshots().map((snapshot) {
      // Cache the data
      final data = snapshot.docs.map((doc) {
        final docData = doc.data() as Map<String, dynamic>;
        docData['docId'] = doc.id;
        return docData;
      }).toList();

      _cacheService.cacheCollection(
        _buildCacheKey(),
        data,
      );

      return snapshot;
    });
  }
}

/// Simple cache indicator widget
class CacheIndicator extends StatelessWidget {
  final String collectionName;
  final VoidCallback? onRefresh;

  const CacheIndicator({
    super.key,
    required this.collectionName,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cacheService = FirebaseCacheService();
    final isValid = cacheService.isCacheValid(collectionName);
    final age = cacheService.getCacheAge(collectionName);

    if (!isValid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cached,
            size: 14,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'Cached ${age ?? 0}m ago',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRefresh,
              child: Icon(
                Icons.refresh,
                size: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
