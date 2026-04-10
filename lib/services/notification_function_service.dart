import 'package:cloud_functions/cloud_functions.dart';

class NotificationFunctionService {
  NotificationFunctionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> sendFcmNotification({
    required String title,
    required String body,
    required String token,
    Map<String, String> data = const {},
  }) async {
    final callable = _functions.httpsCallable(
      'sendFcmNotification',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
    );

    final response = await callable.call(<String, dynamic>{
      'title': title,
      'body': body,
      'token': token,
      'data': data,
    });

    final responseData = response.data;
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }

    return {
      'success': false,
      'message': 'Unexpected response from notification function',
    };
  }
}
