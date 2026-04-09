import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/utils/themes/theme.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final BookingModel booking;

  const BookingConfirmationScreen({super.key, required this.booking});

  String get _qrData => jsonEncode({
        'bookingId': booking.id,
        'workspace': booking.workspaceName,
        'date': DateFormat('yyyy-MM-dd').format(booking.startDate),
        'amount': booking.totalPrice,
      });

  String get _shortId =>
      booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildSuccessHeader(),
                const SizedBox(height: 28),
                _buildTicketCard(),
                const SizedBox(height: 28),
                _buildDoneButton(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: CAppTheme.successColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: CAppTheme.successColor, size: 52),
        ),
        const SizedBox(height: 16),
        Text(
          'Booking Confirmed!',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: CAppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Your workspace has been reserved',
          style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTicketCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
        boxShadow: CAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildTicketTop(),
          _buildDashedDivider(),
          _buildTicketBottom(),
        ],
      ),
    );
  }

  Widget _buildTicketTop() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(CAppTheme.radiusXL)),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          Text(
            booking.workspaceName,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              booking.isHourlyBooking ? 'Hourly Booking' : 'Full Day Booking',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left notch
          Positioned(
            left: -14,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: CAppTheme.backgroundColor, shape: BoxShape.circle),
            ),
          ),
          // Right notch
          Positioned(
            right: -14,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: CAppTheme.backgroundColor, shape: BoxShape.circle),
            ),
          ),
          // Dashed line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashWidth = 6.0;
                final dashSpace = 4.0;
                final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(dashCount, (_) {
                    return Padding(
                      padding: EdgeInsets.only(right: dashSpace),
                      child: SizedBox(
                        width: dashWidth,
                        height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: CAppTheme.borderColor),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketBottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_today_rounded, 'Date', DateFormat('EEE, MMM dd, yyyy').format(booking.startDate)),
          _buildInfoRow(
            Icons.schedule_rounded,
            'Time',
            booking.isHourlyBooking
                ? (booking.timeSlotLabel ?? '${DateFormat('hh:mm a').format(booking.startDate)} - ${DateFormat('hh:mm a').format(booking.endDate)}')
                : 'Full Day',
          ),
          if (booking.categoryType != null)
            _buildInfoRow(Icons.category_rounded, 'Category', booking.categoryType!),
          _buildInfoRow(Icons.event_seat_rounded, 'Seats', '${booking.seatCount}'),
          _buildInfoRow(Icons.receipt_long_rounded, 'Booking ID', '#$_shortId'),
          const SizedBox(height: 4),

          // Price row - highlighted
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Paid', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
                Text(
                  'PKR ${booking.totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: CAppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: CAppTheme.successColor),
                const SizedBox(width: 6),
                Text(
                  booking.status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: CAppTheme.successColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code section
          Text('Scan QR at Workspace', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: CAppTheme.textTertiary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              border: Border.all(color: CAppTheme.borderColor),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: CAppTheme.primaryDark),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: CAppTheme.textPrimary),
              gapless: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: CAppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: CAppTheme.textPrimary),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        style: ElevatedButton.styleFrom(
          backgroundColor: CAppTheme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
          elevation: 0,
        ),
        child: Text('Done', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
