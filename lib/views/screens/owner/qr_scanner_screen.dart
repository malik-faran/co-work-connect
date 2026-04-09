import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:intl/intl.dart' hide TextDirection;

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _hasScanned = true);
    _scannerController.stop();

    try {
      final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
      final bookingId = data['bookingId'] as String?;

      if (bookingId == null || bookingId.isEmpty) {
        _showResultDialog(valid: false, message: 'Invalid QR code - no booking ID found');
        return;
      }

      final booking = await _bookingService.getBookingById(bookingId);
      if (booking == null) {
        _showResultDialog(valid: false, message: 'Booking not found');
        return;
      }

      final payment = await _paymentService.getPaymentByBookingId(bookingId);
      final isPaid = payment != null && payment.status == 'completed';
      final isOwnerReserved = booking.status == 'confirmed' && payment == null;

      _showBookingDetails(booking, isPaid || isOwnerReserved);
    } on FormatException {
      _showResultDialog(valid: false, message: 'Invalid QR code format');
    } catch (e) {
      _showResultDialog(valid: false, message: 'Error verifying booking');
    }
  }

  void _showResultDialog({required bool valid, required String message}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (valid ? CAppTheme.successColor : CAppTheme.errorColor).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: valid ? CAppTheme.successColor : CAppTheme.errorColor,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              valid ? 'Valid Booking' : 'Invalid',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: CAppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetScanner();
                },
                child: const Text('Scan Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BookingModel booking, bool isPaid) {
    if (!mounted) return;

    final isConfirmed = booking.status == 'confirmed';
    final isValid = isConfirmed;
    final isToday = DateUtils.isSameDay(booking.startDate, DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: (isValid ? CAppTheme.successColor : CAppTheme.warningColor).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    color: isValid ? CAppTheme.successColor : CAppTheme.warningColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isValid ? 'Booking Verified' : 'Booking Issue',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: CAppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                if (!isValid)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CAppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      !isConfirmed ? 'Status: ${booking.status.toUpperCase()}' : 'Payment: Not completed',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: CAppTheme.warningColor),
                    ),
                  ),
                const SizedBox(height: 8),

                // Booking details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  child: Column(
                    children: [
                      _detailRow(Icons.workspace_premium_rounded, 'Workspace', booking.workspaceName),
                      _detailRow(Icons.calendar_today_rounded, 'Date', DateFormat('EEE, MMM dd, yyyy').format(booking.startDate)),
                      _detailRow(
                        Icons.schedule_rounded,
                        'Time',
                        booking.isHourlyBooking
                            ? (booking.timeSlotLabel ?? '${DateFormat('hh:mm a').format(booking.startDate)} - ${DateFormat('hh:mm a').format(booking.endDate)}')
                            : 'Full Day',
                      ),
                      _detailRow(Icons.event_seat_rounded, 'Seats', '${booking.seatCount}'),
                      if (booking.categoryType != null)
                        _detailRow(Icons.category_rounded, 'Category', booking.categoryType!),
                      _detailRow(Icons.receipt_long_rounded, 'Booking ID', '#${booking.id.substring(0, 8).toUpperCase()}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Payment & Date status row
                Row(
                  children: [
                    Expanded(
                      child: _statusChip(
                        isPaid ? 'Paid' : 'Unpaid',
                        isPaid ? CAppTheme.successColor : CAppTheme.errorColor,
                        isPaid ? Icons.check_circle : Icons.cancel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusChip(
                        isToday ? 'Today' : DateFormat('MMM dd').format(booking.startDate),
                        isToday ? CAppTheme.successColor : CAppTheme.warningColor,
                        isToday ? Icons.today : Icons.event,
                      ),
                    ),
                  ],
                ),

                // Price
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
                      Text(
                        'PKR ${booking.totalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _resetScanner();
                        },
                        child: const Text('Scan Again'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CAppTheme.primaryColor),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: CAppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() => _hasScanned = false);
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Scan Booking QR', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: CAppTheme.primaryColor,
                borderWidth: 3,
                cutOutSize: 280,
                borderRadius: CAppTheme.radiusXL,
              ),
            ),
          ),

          // Bottom instruction
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                  ),
                  child: Text(
                    'Point camera at booking QR code',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton(
                      icon: Icons.flash_on_rounded,
                      label: 'Flash',
                      onTap: () => _scannerController.toggleTorch(),
                    ),
                    const SizedBox(width: 24),
                    _actionButton(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Flip',
                      onTap: () => _scannerController.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double cutOutSize;
  final double borderRadius;

  const _ScannerOverlayShape({
    required this.borderColor,
    required this.borderWidth,
    required this.cutOutSize,
    required this.borderRadius,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize),
          Radius.circular(borderRadius),
        )),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cutOut = RRect.fromRectAndRadius(
      Rect.fromCenter(center: rect.center, width: cutOutSize, height: cutOutSize),
      Radius.circular(borderRadius),
    );

    // Dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addRRect(cutOut),
    );
    canvas.drawPath(overlayPath, overlayPaint);

    // Border corners
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = cutOutSize * 0.12;
    final cutOutRect = cutOut.outerRect;
    final r = borderRadius;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + cornerLength)
        ..lineTo(cutOutRect.left, cutOutRect.top + r)
        ..arcToPoint(Offset(cutOutRect.left + r, cutOutRect.top), radius: Radius.circular(r))
        ..lineTo(cutOutRect.left + cornerLength, cutOutRect.top),
      borderPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - cornerLength, cutOutRect.top)
        ..lineTo(cutOutRect.right - r, cutOutRect.top)
        ..arcToPoint(Offset(cutOutRect.right, cutOutRect.top + r), radius: Radius.circular(r))
        ..lineTo(cutOutRect.right, cutOutRect.top + cornerLength),
      borderPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.bottom - cornerLength)
        ..lineTo(cutOutRect.left, cutOutRect.bottom - r)
        ..arcToPoint(Offset(cutOutRect.left + r, cutOutRect.bottom), radius: Radius.circular(r))
        ..lineTo(cutOutRect.left + cornerLength, cutOutRect.bottom),
      borderPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - cornerLength, cutOutRect.bottom)
        ..lineTo(cutOutRect.right - r, cutOutRect.bottom)
        ..arcToPoint(Offset(cutOutRect.right, cutOutRect.bottom - r), radius: Radius.circular(r))
        ..lineTo(cutOutRect.right, cutOutRect.bottom - cornerLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
