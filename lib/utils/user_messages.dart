import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// Plain-language message for an exception, instead of showing raw
/// exception text to users (audit UX-04).
String userMessageFor(Object error,
    {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is SocketException || error is TimeoutException) {
    return "You're offline or the connection is slow. Please try again.";
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return "You're offline or the connection is slow. Please try again.";
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'not-found':
        return 'This item no longer exists.';
      case 'resource-exhausted':
      case 'too-many-requests':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
      case 'requires-recent-login':
        return 'Please sign in again and retry.';
    }
  }
  return fallback;
}
