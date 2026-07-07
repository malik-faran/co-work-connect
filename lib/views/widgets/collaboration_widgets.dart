import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Visual helpers shared across the collaboration hub for a consistent,
/// professional look.

class CollabStyle {
  static Color statusColor(String status) {
    switch (status) {
      case 'recruiting':
        return CAppTheme.infoColor;
      case 'active':
        return CAppTheme.successColor;
      case 'completed':
        return CAppTheme.primaryColor;
      case 'cancelled':
        return CAppTheme.textTertiary;
      case 'draft':
        return CAppTheme.warningColor;
      case 'inactive':
        return CAppTheme.textTertiary;
      default:
        return CAppTheme.textSecondary;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'recruiting':
        return 'Recruiting';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'draft':
        return 'Draft';
      case 'inactive':
        return 'Inactive';
      default:
        return status;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'recruiting':
        return Icons.campaign_rounded;
      case 'active':
        return Icons.bolt_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'draft':
        return Icons.edit_note_rounded;
      case 'inactive':
        return Icons.pause_circle_outline_rounded;
      default:
        return Icons.circle;
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;
  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = CollabStyle.statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 7 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CollabStyle.statusIcon(status), size: large ? 16 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            CollabStyle.statusLabel(status),
            style: GoogleFonts.poppins(
              fontSize: large ? 13 : 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final IconData? icon;
  const SkillChip({super.key, required this.label, this.highlighted = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? CAppTheme.successColor : CAppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;
  final Color? ringColor;
  const UserAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.size = 44,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage ? null : CAppTheme.primaryGradient,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
        image: hasImage
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              safeInitial(name),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const SectionCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CAppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CAppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Circular percentage indicator for milestone progress.
class ProgressRing extends StatelessWidget {
  final double percent; // 0..1
  final double size;
  final String? centerLabel;
  const ProgressRing({super.key, required this.percent, this.size = 72, this.centerLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 1),
              strokeWidth: 7,
              backgroundColor: CAppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation(
                percent >= 1 ? CAppTheme.successColor : CAppTheme.primaryColor,
              ),
            ),
          ),
          Text(
            centerLabel ?? '${(percent * 100).round()}%',
            style: GoogleFonts.poppins(
                fontSize: size * 0.22, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}

class MatchBadge extends StatelessWidget {
  final int percent;
  const MatchBadge({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 70
        ? CAppTheme.successColor
        : percent >= 40
            ? CAppTheme.warningColor
            : CAppTheme.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
      ),
      child: Text(
        '$percent% match',
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 300;
        final outerPad = compact ? 12.0 : 24.0;
        final iconBox = compact ? 64.0 : 88.0;
        final iconSize = compact ? 30.0 : 40.0;
        final titleSize = compact ? 15.0 : 17.0;
        final subtitleSize = compact ? 13.0 : 14.0;
        final gapLg = compact ? 12.0 : 20.0;
        final gapSm = compact ? 6.0 : 8.0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: outerPad, vertical: outerPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth > 0 ? constraints.maxWidth - outerPad * 2 : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconSize, color: CAppTheme.primaryColor),
                  ),
                  SizedBox(height: gapLg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: gapSm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: subtitleSize,
                      color: CAppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (action != null) ...[
                    SizedBox(height: gapLg),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
