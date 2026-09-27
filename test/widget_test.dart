import 'package:flutter_test/flutter_test.dart';
import 'package:developer_community_app/utils/app_validators.dart';
import 'package:developer_community_app/utils/content_moderation.dart';
import 'package:developer_community_app/models/avatar_config.dart';
import 'package:developer_community_app/models/poll_model.dart';
import 'package:developer_community_app/core/update/domain/app_update_policy.dart';

void main() {
  group('AppValidators Unit Tests', () {
    test('validateEmail correctly identifies valid and invalid emails', () {
      expect(AppValidators.validateEmail(''), 'Email is required');
      expect(AppValidators.validateEmail('invalid-email'), 'Please enter a valid email');
      expect(AppValidators.validateEmail('test@example.com'), isNull);
      expect(AppValidators.validateEmail('developer.community@domain.co.in'), isNull);
    });

    test('validatePassword validates length requirements', () {
      expect(AppValidators.validatePassword(''), 'Password is required');
      expect(AppValidators.validatePassword('12345'), 'Password must be at least 6 characters');
      expect(AppValidators.validatePassword('securePassword123'), isNull);
    });

    test('validateUsername validates length and format', () {
      expect(AppValidators.validateUsername(''), 'Username is required');
      expect(AppValidators.validateUsername('ab'), 'Username must be at least 3 characters');
      expect(AppValidators.validateUsername('valid_user123'), isNull);
    });
  });

  group('ContentModerationService Unit Tests', () {
    test('rejects empty and overly short input', () {
      final emptyResult = ContentModerationService.analyzeField('', minLength: 5);
      expect(emptyResult.qualityScore, 0.0);
      expect(emptyResult.shouldReject, isTrue);

      final shortResult = ContentModerationService.analyzeField('hi', minLength: 10);
      expect(shortResult.flags, contains('too_short'));
    });

    test('detects blocked content patterns', () {
      final blockedResult = ContentModerationService.analyzeField('this contains suicide trigger', minLength: 5);
      expect(blockedResult.isBlocked, isTrue);
      expect(blockedResult.status, ModerationStatus.blocked);
      expect(blockedResult.shouldReject, isTrue);
    });

    test('approves healthy technical text', () {
      final cleanText = 'How do I optimize Firestore stream subscriptions in a high traffic Flutter app?';
      final cleanResult = ContentModerationService.analyzeField(cleanText, minLength: 10);
      expect(cleanResult.isBlocked, isFalse);
      expect(cleanResult.status, ModerationStatus.approved);
      expect(cleanResult.qualityScore, greaterThanOrEqualTo(0.7));
    });
  });

  group('AvatarConfig Unit Tests', () {
    test('defaults factory generates expected DiceBear URL', () {
      final config = AvatarConfig.defaults();
      expect(config.seed, 'DevSphere');
      expect(config.style, 'adventurer');
      expect(config.backgroundColor, 'b6e3f4');
      expect(config.avatarUrl, contains('api.dicebear.com/7.x/adventurer/png?seed=DevSphere'));
      expect(config.avatarUrl, contains('backgroundColor=b6e3f4'));
    });

    test('JSON serialization and deserialization roundtrip', () {
      const original = AvatarConfig(
        seed: 'flutter_dev',
        style: 'bottts',
        backgroundColor: 'ff0000',
        hair: 'short',
      );
      final jsonStr = original.toJsonString();
      final restored = AvatarConfig.fromJsonString(jsonStr);

      expect(restored.seed, original.seed);
      expect(restored.style, original.style);
      expect(restored.backgroundColor, original.backgroundColor);
      expect(restored.hair, original.hair);
    });
  });

  group('PollModel Unit Tests', () {
    test('calculates total votes and user vote state accurately', () {
      final poll = Poll(
        id: 'poll_1',
        question: 'Which state management do you prefer?',
        creatorId: 'user_admin',
        createdAt: DateTime.now(),
        options: const [
          PollOption(id: 'opt_1', text: 'Riverpod', voterIds: ['u1', 'u2']),
          PollOption(id: 'opt_2', text: 'Bloc', voterIds: ['u3']),
          PollOption(id: 'opt_3', text: 'Provider', voterIds: []),
        ],
      );

      expect(poll.totalVotes, 3);
      expect(poll.hasUserVoted('u1'), isTrue);
      expect(poll.hasUserVoted('u4'), isFalse);
      expect(poll.getUserVote('u3'), 'opt_2');
      expect(poll.getUserVote('u99'), isNull);
    });

    test('expiry check correctly reflects timeline', () {
      final activePoll = Poll(
        id: 'poll_active',
        question: 'Active poll',
        creatorId: 'u1',
        createdAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(days: 2)),
        options: const [],
      );
      expect(activePoll.isExpired, isFalse);
      expect(activePoll.isActive, isTrue);

      final expiredPoll = Poll(
        id: 'poll_expired',
        question: 'Expired poll',
        creatorId: 'u1',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        endsAt: DateTime.now().subtract(const Duration(days: 1)),
        options: const [],
      );
      expect(expiredPoll.isExpired, isTrue);
      expect(expiredPoll.isActive, isFalse);
    });
  });

  group('AppUpdatePolicy Unit Tests', () {
    test('holds expected Play Store constants', () {
      expect(AppUpdatePolicy.playStoreAppId, 'com.vanshdevstudio.devsphere');
      expect(AppUpdatePolicy.playStoreUrl, contains('com.vanshdevstudio.devsphere'));
      expect(AppUpdatePolicy.playStoreMarketUrl, 'market://details?id=com.vanshdevstudio.devsphere');
    });
  });
}
