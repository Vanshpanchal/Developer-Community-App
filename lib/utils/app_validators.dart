import 'content_moderation.dart';

class AppValidators {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateTitle(String? value) {
    final requiredError = validateRequired(value, 'Title');
    if (requiredError != null) {
      return requiredError;
    }

    final result = ContentModerationService.analyzeField(value, minLength: 5);
    if (result.isBlocked) {
      return result.userMessage;
    }
    if (result.qualityScore < 0.35) {
      return 'Title must be meaningful and at least 5 characters';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final requiredError = validateRequired(value, 'Description');
    if (requiredError != null) {
      return requiredError;
    }

    final result = ContentModerationService.analyzeField(value, minLength: 12);
    if (result.isBlocked) {
      return result.userMessage;
    }
    if (result.qualityScore < 0.35) {
      return 'Description must clearly explain the problem or topic';
    }
    return null;
  }

  static String? validateListNotEmpty(List items, String fieldName) {
    if (items.isEmpty) {
      return '$fieldName cannot be empty';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Deliberately permissive (allows +tags and long TLDs); Firebase Auth
    // performs the authoritative check.
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  /// Minimum length for new passwords.
  static const int minPasswordLength = 8;

  /// Sign-in only checks presence, so accounts created under the older
  /// 6-character minimum can still log in.
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  static String? validateConfirmPassword(
      String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Confirm your password';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }
}
