import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/password_validator.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final score = PasswordValidator.score(password);
    final (label, color) = _labelAndColor(score);

    final rules = <({String text, bool ok})>[
      (text: 'At least 8 characters', ok: PasswordValidator.hasMinLength(password)),
      (text: 'One uppercase letter (A-Z)', ok: PasswordValidator.hasUpper(password)),
      (text: 'One lowercase letter (a-z)', ok: PasswordValidator.hasLower(password)),
      (text: 'One number (0-9)', ok: PasswordValidator.hasDigit(password)),
      (text: 'One special character (!@#\$…)', ok: PasswordValidator.hasSpecial(password)),
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: password.isEmpty ? 0 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) {
              final active = i < score;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active ? color : CAppTheme.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                'Strength: $label',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      r.ok ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: r.ok ? CAppTheme.successColor : CAppTheme.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.text,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: r.ok ? CAppTheme.textPrimary : CAppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  (String, Color) _labelAndColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return ('Very Weak', CAppTheme.errorColor);
      case 2:
        return ('Weak', const Color(0xFFF97316));
      case 3:
        return ('Fair', CAppTheme.warningColor);
      case 4:
        return ('Good', const Color(0xFF0EA5E9));
      case 5:
      default:
        return ('Strong', CAppTheme.successColor);
    }
  }
}
