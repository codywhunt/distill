/// Result of validating a value.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.error(this.errorMessage) : isValid = false;
}

/// A function that validates a value.
typedef Validator<T> = ValidationResult Function(T? value);

/// Common validators for input fields.
class Validators {
  const Validators._();

  /// Validates that a number is within a range (inclusive).
  static Validator<num> range(num min, num max) {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (value < min || value > max) {
        return ValidationResult.error('Value must be between $min and $max');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a number is positive (> 0).
  static Validator<num> positive() {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (value <= 0) {
        return ValidationResult.error('Value must be positive');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a number is non-negative (>= 0).
  static Validator<num> nonNegative() {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (value < 0) {
        return ValidationResult.error('Value must be non-negative');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a string is not empty.
  static Validator<String> notEmpty() {
    return (value) {
      if (value == null || value.isEmpty) {
        return ValidationResult.error('This field is required');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a string matches a pattern.
  static Validator<String> pattern(RegExp regex, String errorMessage) {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (!regex.hasMatch(value)) {
        return ValidationResult.error(errorMessage);
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a string has a minimum length.
  static Validator<String> minLength(int min) {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (value.length < min) {
        return ValidationResult.error(
            'Must be at least $min character${min == 1 ? '' : 's'}');
      }
      return const ValidationResult.valid();
    };
  }

  /// Validates that a string has a maximum length.
  static Validator<String> maxLength(int max) {
    return (value) {
      if (value == null) return const ValidationResult.valid();
      if (value.length > max) {
        return ValidationResult.error(
            'Must be at most $max character${max == 1 ? '' : 's'}');
      }
      return const ValidationResult.valid();
    };
  }

  /// Combines multiple validators. All must pass for the result to be valid.
  static Validator<T> combine<T>(List<Validator<T>> validators) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (!result.isValid) return result;
      }
      return const ValidationResult.valid();
    };
  }
}
