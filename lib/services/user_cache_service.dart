import 'package:cloud_firestore/cloud_firestore.dart';

class UserCacheService {
  UserCacheService._internal();
  static final UserCacheService instance = UserCacheService._internal();
  factory UserCacheService() => instance;

  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, Future<Map<String, dynamic>>> _pendingFetches = {};

  Future<Map<String, dynamic>> getUserData(String uid) async {
    if (_cache.containsKey(uid)) {
      return _cache[uid]!;
    }
    
    if (_pendingFetches.containsKey(uid)) {
      return await _pendingFetches[uid]!;
    }

    final fetchFuture = _fetchFromFirestore(uid);
    _pendingFetches[uid] = fetchFuture;
    
    try {
      final data = await fetchFuture;
      _cache[uid] = data;
      return data;
    } finally {
      _pendingFetches.remove(uid);
    }
  }

  Future<Map<String, dynamic>> _fetchFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('User').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (_) {}
    
    return {
      'Username': 'Unknown User',
      'profilePicture': null,
      'XP': 100, // fallback
    };
  }

  // Pre-populate if denormalized data is available
  void populate(String uid, Map<String, dynamic> data) {
    if (!_cache.containsKey(uid)) {
      _cache[uid] = data;
    }
  }

  /// Removes the cached entry for [uid] so the next call fetches fresh data.
  void invalidate(String uid) {
    _cache.remove(uid);
    _pendingFetches.remove(uid);
  }

  /// Clears the entire user cache map.
  void clearAll() {
    _cache.clear();
    _pendingFetches.clear();
  }

  /// Patches a specific field in the in-memory cache without a network call.
  /// Useful for immediate UI reflection after a local write.
  void patch(String uid, Map<String, dynamic> patch) {
    if (_cache.containsKey(uid)) {
      _cache[uid] = {..._cache[uid]!, ...patch};
    }
  }
}
