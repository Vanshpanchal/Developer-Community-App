import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrates all 'XP' fields in the 'User' collection from String to Integer.
  /// Can be called once from the app's initialization or via a debug button.
  static Future<void> migrateXpToInteger() async {
    debugPrint('🚀 Starting XP Migration: String -> Integer');
    int count = 0;

    try {
      final snapshot = await _firestore.collection('User').get();
      
      final batch = _firestore.batch();
      int batchCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawXp = data['XP'];

        if (rawXp is String) {
          final intXp = int.tryParse(rawXp) ?? 0;
          batch.update(doc.reference, {'XP': intXp});
          batchCount++;
          count++;

          // Firestore batch limit is 500
          if (batchCount >= 400) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint('✅ XP Migration Complete. Migrated $count documents.');
    } catch (e) {
      debugPrint('❌ XP Migration Failed: $e');
    }
  }
}
