abstract final class FormValidators {
  static String? requiredText(String? value, {required String message}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? password(String? value, {bool requireMinimumLength = false}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (requireMinimumLength && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm password is required';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? category(String? value) =>
      value == null || value.isEmpty ? 'Please choose a category' : null;

  static String? difficulty(String? value) =>
      value == null || value.isEmpty ? 'Please choose a difficulty' : null;

  static String? recipeName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.length > 80) return 'Name must be at most 80 characters';
    return null;
  }

  static String? cookTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Cook time is required';
    final minutes = int.tryParse(value.trim());
    if (minutes == null || minutes < 1 || minutes > 600) {
      return 'Cook time must be a whole number from 1 to 600';
    }
    return null;
  }

  static String? servings(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final count = int.tryParse(value.trim());
    if (count == null || count < 1 || count > 20) {
      return 'Servings must be a whole number from 1 to 20';
    }
    return null;
  }

  static String? notes(String? value) {
    if ((value ?? '').length > 300) return 'Notes must be at most 300 characters';
    return null;
  }
}
