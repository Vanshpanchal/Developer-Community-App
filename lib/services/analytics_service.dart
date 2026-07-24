import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:developer_community_app/utils/app_logger.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      AppLogger.debug('Analytics Event: $name, Params: $parameters');
    } catch (e) {
      AppLogger.warning('Analytics Error: $e');
    }
  }

  Future<void> logLogin({String? method}) async {
    await _analytics.logLogin(loginMethod: method);
    AppLogger.debug('Analytics Event: Login ($method)');
  }

  Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
    AppLogger.debug('Analytics Event: SignUp ($method)');
  }

  Future<void> logScreenView({required String screenName}) async {
    await _analytics.logScreenView(screenName: screenName);
    AppLogger.debug('Analytics Screen: $screenName');
  }

  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  Future<void> setUserId({required String id}) async {
    await _analytics.setUserId(id: id);
  }
}
