import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';

/// Firebase Cache Service
/// Provides intelligent caching for Firestore data with automatic refresh on updates
class FirebaseCacheService {
  static final FirebaseCacheService _instance =
      FirebaseCacheService._internal();
  factory FirebaseCacheService() => _instance;
  FirebaseCacheService._internal();

  final _storage = GetStorage();
  final Map<String, Stream<QuerySnapshot>> _activeStreams = {};
  final Map<String, DateTime> _lastFetchTimes = {};

  // Cache duration in minutes
  static const int CACHE_DURATION_MINUTES = 5;
  static const String CACHE_PREFIX = 'cache_';
  static const String TIMESTAMP_PREFIX = 'timestamp_';

  /// Cache a collection from Firestore
  Future<void> cacheCollection(
      String collectionName, List<Map<String, dynamic>> data) async {
    try {
      final cacheKey = '$CACHE_PREFIX$collectionName';
      final timestampKey = '$TIMESTAMP_PREFIX$collectionName';

      await _storage.write(cacheKey, jsonEncode(data));
      await _storage.write(timestampKey, DateTime.now().toIso8601String());

      print('✅ Cached $collectionName with ${data.length} items');
    } catch (e) {
      print('❌ Error caching $collectionName: $e');
    }
  }

  /// Get cached data for a collection
  List<Map<String, dynamic>>? getCachedCollection(String collectionName) {
    try {
      final cacheKey = '$CACHE_PREFIX$collectionName';
      final timestampKey = '$TIMESTAMP_PREFIX$collectionName';

      final cachedData = _storage.read(cacheKey);
      final timestampStr = _storage.read(timestampKey);

      if (cachedData == null || timestampStr == null) {
        return null;
      }

      // Check if cache is expired
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final difference = now.difference(timestamp).inMinutes;

      if (difference > CACHE_DURATION_MINUTES) {
        print('⏰ Cache expired for $collectionName');
        return null;
      }

      final List<dynamic> decodedData = jsonDecode(cachedData);
      return decodedData.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Error reading cache for $collectionName: $e');
      return null;
    }
  }

  /// Get or fetch collection with caching
  Future<List<Map<String, dynamic>>> getOrFetchCollection({
    required String collectionName,
    Map<String, dynamic>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    final cacheKey = _buildCacheKey(collectionName, where, orderBy, limit);

    // Try to get from cache first
    final cached = getCachedCollection(cacheKey);
    if (cached != null) {
      print('📦 Retrieved from cache: $cacheKey');

      // Fetch fresh data in background
      _fetchAndUpdateCache(
        collectionName: collectionName,
        cacheKey: cacheKey,
        where: where,
        orderBy: orderBy,
        descending: descending,
        limit: limit,
      );

      return cached;
    }

    // Fetch from Firestore
    print('🌐 Fetching from Firestore: $cacheKey');
    return await _fetchFromFirestore(
      collectionName: collectionName,
      cacheKey: cacheKey,
      where: where,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );
  }

  /// Fetch data from Firestore
  Future<List<Map<String, dynamic>>> _fetchFromFirestore({
    required String collectionName,
    required String cacheKey,
    Map<String, dynamic>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collectionName);

      // Apply where clauses
      if (where != null) {
        where.forEach((field, value) {
          query = query.where(field, isEqualTo: value);
        });
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final data = snapshot.docs.map((doc) {
        final docData = doc.data() as Map<String, dynamic>;
        docData['docId'] = doc.id;
        return docData;
      }).toList();

      // Cache the data
      await cacheCollection(cacheKey, data);

      return data;
    } catch (e) {
      print('❌ Error fetching from Firestore: $e');
      return [];
    }
  }

  /// Fetch and update cache in background
  Future<void> _fetchAndUpdateCache({
    required String collectionName,
    required String cacheKey,
    Map<String, dynamic>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    final data = await _fetchFromFirestore(
      collectionName: collectionName,
      cacheKey: cacheKey,
      where: where,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );

    // The caching is already done in _fetchFromFirestore
    print('🔄 Updated cache for $cacheKey');
  }

  /// Listen to collection changes with caching
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required String collectionName,
    Map<String, dynamic>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    final cacheKey = _buildCacheKey(collectionName, where, orderBy, limit);

    Query query = FirebaseFirestore.instance.collection(collectionName);

    // Apply where clauses
    if (where != null) {
      where.forEach((field, value) {
        query = query.where(field, isEqualTo: value);
      });
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final data = snapshot.docs.map((doc) {
        final docData = doc.data() as Map<String, dynamic>;
        docData['docId'] = doc.id;
        return docData;
      }).toList();

      // Update cache when data changes
      cacheCollection(cacheKey, data);

      return data;
    });
  }

  /// Build cache key based on query parameters
  String _buildCacheKey(String collectionName, Map<String, dynamic>? where,
      String? orderBy, int? limit) {
    final parts = [collectionName];

    if (where != null && where.isNotEmpty) {
      where.forEach((key, value) {
        parts.add('${key}_$value');
      });
    }

    if (orderBy != null) {
      parts.add('order_$orderBy');
    }

    if (limit != null) {
      parts.add('limit_$limit');
    }

    return parts.join('_');
  }

  /// Clear cache for a specific collection
  Future<void> clearCache(String collectionName) async {
    final cacheKey = '$CACHE_PREFIX$collectionName';
    final timestampKey = '$TIMESTAMP_PREFIX$collectionName';

    await _storage.remove(cacheKey);
    await _storage.remove(timestampKey);

    print('🗑️ Cleared cache for $collectionName');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await _storage.erase();
    print('🗑️ Cleared all cache');
  }

  /// Check if cache exists and is valid
  bool isCacheValid(String collectionName) {
    final timestampKey = '$TIMESTAMP_PREFIX$collectionName';
    final timestampStr = _storage.read(timestampKey);

    if (timestampStr == null) return false;

    final timestamp = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final difference = now.difference(timestamp).inMinutes;

    return difference <= CACHE_DURATION_MINUTES;
  }

  /// Get cache age in minutes
  int? getCacheAge(String collectionName) {
    final timestampKey = '$TIMESTAMP_PREFIX$collectionName';
    final timestampStr = _storage.read(timestampKey);

    if (timestampStr == null) return null;

    final timestamp = DateTime.parse(timestampStr);
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes;
  }

  /// Prefetch and cache multiple collections
  Future<void> prefetchCollections(List<String> collectionNames) async {
    print('🚀 Prefetching ${collectionNames.length} collections...');

    for (final collectionName in collectionNames) {
      await getOrFetchCollection(collectionName: collectionName);
    }

    print('✅ Prefetch completed');
  }
}
