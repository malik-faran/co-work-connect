import 'package:flutter/material.dart';
import 'package:cwc/utils/themes/theme.dart';

void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: CAppTheme.errorColor,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: CAppTheme.successColor,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}

void showInfoSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: CAppTheme.infoColor,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}

void showWarningSnackBar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: CAppTheme.warningColor,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );
}
