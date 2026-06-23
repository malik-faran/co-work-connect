import 'package:flutter/services.dart';
import 'package:cwc/utils/constants/validation_constants.dart';
import 'package:cwc/utils/validators/password_validator.dart';

/// Shared form validators — blocks dummy/placeholder data and enforces limits.
class FormValidators {
  FormValidators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _nameCharsRegex = RegExp(r"^[a-zA-Z .'-]+$");

  static final RegExp _phoneRegex = RegExp(r'^(\+92|0)?3[0-9]{9}$');

  static final Set<String> _dummyWords = {
    'test',
    'testing',
    'tester',
    'dummy',
    'sample',
    'asdf',
    'asdfg',
    'qwerty',
    'abc',
    'abcd',
    'user',
    'admin',
    'null',
    'none',
    'na',
    'n/a',
    'xyz',
    'lorem',
    'ipsum',
    'foo',
    'bar',
    'placeholder',
    'temp',
    'temporary',
    'aaa',
    'aaaa',
    'bbbb',
  };

  static final RegExp _repeatedChar = RegExp(r'^(.)\1{3,}$');

  /// Returns true when text looks like placeholder / dummy input.
  static bool isDummyText(String value) {
    final t = value.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (_dummyWords.contains(t)) return true;
    if (_repeatedChar.hasMatch(t)) return true;
    if (RegExp(r'^[0-9]+$').hasMatch(t)) return true;
    return false;
  }

  static String? _dummyError(String label) =>
      'Please enter a real $label (not test/dummy data)';

  // ── Person / business ──────────────────────────────────────────────

  static String? name(String? value, {String label = 'name'}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter your $label';
    if (t.length < ValidationLimits.nameMin) {
      return '$label must be at least ${ValidationLimits.nameMin} characters';
    }
    if (t.length > ValidationLimits.nameMax) {
      return '$label is too long (max ${ValidationLimits.nameMax})';
    }
    if (!_nameCharsRegex.hasMatch(t)) {
      return 'Only letters, spaces, . \' - allowed';
    }
    if (isDummyText(t)) return _dummyError(label);
    return null;
  }

  static String? businessName(String? value, {bool required = true}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) {
      return required ? 'Business name is required' : null;
    }
    if (t.length < ValidationLimits.businessNameMin) {
      return 'Business name must be at least ${ValidationLimits.businessNameMin} characters';
    }
    if (t.length > ValidationLimits.businessNameMax) {
      return 'Business name is too long';
    }
    if (isDummyText(t)) return _dummyError('business name');
    return null;
  }

  static String? email(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(t)) return 'Please enter a valid email';
    return null;
  }

  static String? phone(String? value, {bool required = true}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    final digits = t.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_phoneRegex.hasMatch(digits)) {
      return 'Enter a valid Pakistan mobile (03XX XXXXXXX)';
    }
    return null;
  }

  static String? password(String? value) => PasswordValidator.validate(value);

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) return 'Passwords do not match';
    return null;
  }

  // ── Workspace ──────────────────────────────────────────────────────

  static String? workspaceName(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter workspace name';
    if (t.length < ValidationLimits.workspaceNameMin) {
      return 'Name must be at least ${ValidationLimits.workspaceNameMin} characters';
    }
    if (t.length > ValidationLimits.workspaceNameMax) {
      return 'Name is too long (max ${ValidationLimits.workspaceNameMax})';
    }
    if (isDummyText(t)) return _dummyError('workspace name');
    return null;
  }

  static String? description(
    String? value, {
    int min = ValidationLimits.descriptionMin,
    int max = ValidationLimits.descriptionMax,
    String label = 'Description',
    bool required = true,
  }) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return required ? '$label is required' : null;
    if (t.length < min) {
      return '$label must be at least $min characters';
    }
    if (t.length > max) {
      return '$label cannot exceed $max characters';
    }
    if (isDummyText(t)) return _dummyError(label.toLowerCase());
    return null;
  }

  static String? address(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) {
      return 'Please pick location on map or enter address';
    }
    if (t.length < ValidationLimits.addressMin) {
      return 'Address is too short — add street/area details';
    }
    if (t.length > ValidationLimits.addressMax) {
      return 'Address is too long';
    }
    if (isDummyText(t)) return _dummyError('address');
    return null;
  }

  static String? positiveInt(
    String? value, {
    required bool required,
    int min = 1,
    int max = 999999,
    String label = 'Value',
  }) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return required ? '$label is required' : null;
    final n = int.tryParse(t);
    if (n == null) return 'Enter a valid whole number';
    if (n < 0) return '$label cannot be negative';
    if (n < min) return '$label must be at least $min';
    if (n > max) return '$label cannot exceed $max';
    return null;
  }

  static String? price(
    String? value, {
    required bool required,
    double min = 1,
    double max = 999999999,
    String label = 'Price',
  }) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return required ? '$label is required' : null;
    final n = double.tryParse(t);
    if (n == null) return 'Enter a valid amount';
    if (n < 0) return '$label cannot be negative';
    if (n < min) return '$label must be at least Rs. ${min.toInt()}';
    if (n > max) return '$label cannot exceed Rs. ${max.toInt()}';
    return null;
  }

  // ── Collaboration ──────────────────────────────────────────────────

  static String? collabTitle(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter a title';
    if (t.length < ValidationLimits.collabTitleMin) {
      return 'Title must be at least ${ValidationLimits.collabTitleMin} characters';
    }
    if (t.length > ValidationLimits.collabTitleMax) {
      return 'Title is too long';
    }
    if (isDummyText(t)) return _dummyError('title');
    return null;
  }

  static String? collabDescription(String? value) {
    return description(
      value,
      min: ValidationLimits.collabDescriptionMin,
      max: ValidationLimits.collabDescriptionMax,
      label: 'Description',
    );
  }

  static String? collabResponse(String? value) {
    return description(
      value,
      min: ValidationLimits.collabResponseMin,
      max: ValidationLimits.collabResponseMax,
      label: 'Response',
    );
  }

  static String? optionalShortText(
    String? value, {
    String label = 'Field',
    int max = ValidationLimits.collabOptionalTextMax,
  }) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    if (t.length < 2) return '$label is too short';
    if (t.length > max) return '$label cannot exceed $max characters';
    if (isDummyText(t)) return _dummyError(label.toLowerCase());
    return null;
  }

  // ── Review & chat ──────────────────────────────────────────────────

  static String? reviewComment(String? value, {required bool required}) {
    final t = (value ?? '').trim();
    if (!required) {
      if (t.isEmpty) return null;
      if (t.length < ValidationLimits.reviewCommentMin) {
        return 'Please write at least ${ValidationLimits.reviewCommentMin} characters';
      }
      if (isDummyText(t)) return _dummyError('feedback');
      return null;
    }
    if (t.isEmpty) return 'Feedback is required for this rating';
    if (t.length < ValidationLimits.reviewCommentMin) {
      return 'Please write at least ${ValidationLimits.reviewCommentMin} characters';
    }
    if (t.length > ValidationLimits.reviewCommentMax) {
      return 'Feedback cannot exceed ${ValidationLimits.reviewCommentMax} characters';
    }
    if (isDummyText(t)) return _dummyError('feedback');
    return null;
  }

  static String? chatMessage(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Message cannot be empty';
    if (t.length > ValidationLimits.chatMessageMax) {
      return 'Message is too long (max ${ValidationLimits.chatMessageMax} chars)';
    }
    return null;
  }

  // ── Input formatters ───────────────────────────────────────────────

  static List<TextInputFormatter> digitsOnly() => [
        FilteringTextInputFormatter.digitsOnly,
      ];

  static List<TextInputFormatter> decimalPrice() => [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ];
}
