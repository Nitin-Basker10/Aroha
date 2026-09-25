/// Central input validation utilities for AROHA
class Validators {
  Validators._();

  /// Validate consumption quantity
  static String? validateConsumption(double? amount, double currentStock) {
    if (amount == null) {
      return 'Please enter a valid number';
    }
    if (amount.isNaN || amount.isInfinite) {
      return 'Invalid consumption amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than zero';
    }
    if (amount > currentStock) {
      return 'Amount exceeds current stock (${currentStock.toStringAsFixed(1)})';
    }
    return null;
  }

  /// Validate daily burn rate
  static String? validateBurnRate(double? rate) {
    if (rate == null) {
      return 'Please enter a valid burn rate';
    }
    if (rate.isNaN || rate.isInfinite) {
      return 'Invalid burn rate';
    }
    if (rate < 0) {
      return 'Burn rate cannot be negative';
    }
    return null;
  }

  /// Validate email address
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate required text field
  static String? validateRequired(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName cannot be empty';
    }
    return null;
  }

  /// Validate positive number string
  static String? validatePositiveNumber(
    String? value, [
    String fieldName = 'Value',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return '$fieldName must be a valid number';
    }
    if (parsed <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }
}
