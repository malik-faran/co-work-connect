import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/review_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/refund_policy.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/reviews/review_dialog.dart';
import 'package:cwc/views/screens/payment/payment_screen.dart';
import 'package:cwc/views/screens/booking/booking_confirmation_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final ReviewService _reviewService = ReviewService();
  final PaymentService _paymentService = PaymentService();
  final WalletService _walletService = WalletService();
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, PaymentModel?> _paymentMap = {};
  final Map<String, bool> _reviewCache = {};
  late TabController _tabController;
  StreamSubscription<List<BookingModel>>? _bookingStreamSub;
  Timer? _refundTimer;

  final _tabs = const ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadBookings();
    _setupStream();
    _refundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _setupStream() {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    _bookingStreamSub = _bookingService.getUserBookingsStream(userId).listen(
      (data) {
        if (mounted && data.isNotEmpty) {
          _loadBookings();
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _refundTimer?.cancel();
    _bookingStreamSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) { setState(() => _isLoading = false); return; }

    if (mounted && _errorMessage != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bookings = await _bookingService.getUserBookings(userId);
      final payMap = <String, PaymentModel?>{};
      for (var b in bookings) {
        try { payMap[b.id] = await _paymentService.getPaymentByBookingId(b.id); }
        catch (_) { payMap[b.id] = null; }
      }
      if (mounted) {
        bookings.sort((a, b) {
          final aDate = a.bookingDateKey ?? DateFormat('yyyy-MM-dd').format(a.startDate);
          final bDate = b.bookingDateKey ?? DateFormat('yyyy-MM-dd').format(b.startDate);
          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) return byDate;
          return b.createdAt.compareTo(a.createdAt);
        });
        setState(() {
          _bookings = bookings;
          _paymentMap = payMap;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<BookingModel> _filteredBookings(int tabIndex) {
    switch (tabIndex) {
      case 1: return _bookings.where((b) => b.status == AppConstants.bookingStatusPending || b.status == AppConstants.bookingStatusConfirmed).toList();
      case 2: return _bookings.where((b) => b.status == AppConstants.bookingStatusCompleted).toList();
      case 3: return _bookings.where((b) => b.status == AppConstants.bookingStatusCancelled).toList();
      default: return _bookings;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.bookingStatusConfirmed: return CAppTheme.successColor;
      case AppConstants.bookingStatusPending: return CAppTheme.warningColor;
      case AppConstants.bookingStatusCancelled: return CAppTheme.errorColor;
      case AppConstants.bookingStatusCompleted: return CAppTheme.primaryColor;
      default: return CAppTheme.textTertiary;
    }
  }

  DateTime _bookingDisplayDate(BookingModel booking) {
    final key = booking.bookingDateKey;
    if (key != null && key.length >= 10) {
      try {
        final p = key.split('-');
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      } catch (_) {}
    }
    return booking.startDate;
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('My Bookings', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (i) => _buildBookingList(userId, i)),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CAppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: CAppTheme.errorColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookings,
              style: ElevatedButton.styleFrom(
                backgroundColor: CAppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(String userId, int tabIndex) {
    final filtered = _filteredBookings(tabIndex);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.book_outlined, size: 56, color: CAppTheme.textTertiary),
            const SizedBox(height: 12),
            Text('No bookings', style: GoogleFonts.poppins(fontSize: 16, color: CAppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: CAppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _BookingCard(
          booking: filtered[index],
          displayDate: _bookingDisplayDate(filtered[index]),
          statusColor: _statusColor(filtered[index].status),
          payment: _paymentMap[filtered[index].id],
          reviewService: _reviewService,
          reviewCache: _reviewCache,
          onPayTap: () => _navigateToPayment(filtered[index]),
          onReviewTap: () => _showReviewDialog(filtered[index]),
          onViewTicket: () => _viewTicket(filtered[index]),
          onCancelRefund: () => _requestCancelRefund(filtered[index]),
        ),
      ),
    );
  }

  Future<void> _navigateToPayment(BookingModel booking) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(booking: booking)));
    if (result == true) _loadBookings();
  }

  Future<void> _showReviewDialog(BookingModel booking) async {
    final result = await showDialog<bool>(context: context, builder: (_) => ReviewDialog(booking: booking));
    if (result == true) _loadBookings();
  }

  void _viewTicket(BookingModel booking) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookingConfirmationScreen(booking: booking)));
  }

  Future<void> _requestCancelRefund(BookingModel booking) async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;

    final payment = _paymentMap[booking.id];
    if (payment == null || payment.status != 'completed') {
      showErrorSnackBar(context, 'Refund is only available for paid bookings.');
      return;
    }

    if (!booking.canCancelWithRefund(isPaid: true)) {
      showErrorSnackBar(
        context,
        'Cancellation window closed. Cancel at least ${RefundPolicy.leadTimeLabel(booking.startDate)} before your booking starts.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel & Request Refund?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Your refund of Rs. ${booking.totalPrice.toStringAsFixed(0)} will be reviewed by the CWC team. If approved, it will be credited to your in-app wallet (Profile → My Wallet).\n\nCancel at least ${RefundPolicy.leadTimeLabel(booking.startDate)} before the booking start time.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request Refund')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _walletService.requestRefund(
        userId: userId,
        bookingId: booking.id,
        paymentId: payment.id,
        amount: booking.totalPrice,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Refund request submitted. CWC team will review it.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final DateTime displayDate;
  final Color statusColor;
  final PaymentModel? payment;
  final ReviewService reviewService;
  final Map<String, bool> reviewCache;
  final VoidCallback onPayTap;
  final VoidCallback onReviewTap;
  final VoidCallback onViewTicket;
  final VoidCallback onCancelRefund;

  const _BookingCard({
    required this.booking,
    required this.displayDate,
    required this.statusColor, this.payment, required this.reviewService, required this.reviewCache, required this.onPayTap, required this.onReviewTap, required this.onViewTicket, required this.onCancelRefund});

  @override
  Widget build(BuildContext context) {
    final canReview = booking.status == AppConstants.bookingStatusCompleted || booking.status == AppConstants.bookingStatusConfirmed;
    final isPaid = payment?.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.workspaces_outlined, color: CAppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.workspaceName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        booking.isHourlyBooking
                            ? '${booking.durationHours ?? 0}h · Rs. ${booking.totalPrice.toStringAsFixed(0)}'
                            : '${booking.numberOfDays}d · Rs. ${booking.totalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(booking.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: CAppTheme.textTertiary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat('EEE, MMM dd, yyyy').format(displayDate),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CAppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (booking.timeSlotLabel != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_outlined, size: 14, color: CAppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      booking.timeSlotLabel!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            if (booking.status == AppConstants.bookingStatusPending) ...[
              const Divider(height: 24),
              _buildPaymentStatus(),
            ],

            if ((booking.status == AppConstants.bookingStatusConfirmed || booking.status == AppConstants.bookingStatusCompleted) && (isPaid || payment == null)) ...[
              const Divider(height: 24),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: onViewTicket,
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: Text('View Ticket', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: const BorderSide(color: CAppTheme.primaryColor),
                    foregroundColor: CAppTheme.primaryColor,
                  ),
                ),
              ),
            ],

            if (booking.status == AppConstants.bookingStatusConfirmed && isPaid) ...[
              const SizedBox(height: 10),
              if (booking.canCancelWithRefund(isPaid: true)) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: CAppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: CAppTheme.warningColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Refund window: ${RefundPolicy.formatDuration(booking.refundWindowRemaining)} left',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CAppTheme.warningColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCancelRefund,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text('Cancel & Request Refund', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CAppTheme.errorColor,
                      side: BorderSide(color: CAppTheme.errorColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: CAppTheme.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cancellation closed — must cancel ${RefundPolicy.leadTimeLabel(booking.startDate)} before start',
                          style: GoogleFonts.poppins(fontSize: 11, color: CAppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (canReview) ...[
              const Divider(height: 24),
              _buildReviewSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    if (reviewCache.containsKey(booking.id)) {
      if (reviewCache[booking.id] == true) {
        return Row(children: [
          const Icon(Icons.check_circle, size: 16, color: CAppTheme.successColor),
          const SizedBox(width: 6),
          Flexible(child: Text('Review submitted', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor, fontWeight: FontWeight.w600))),
        ]);
      }
      return SizedBox(
        height: 36,
        child: OutlinedButton.icon(
          onPressed: onReviewTap,
          icon: const Icon(Icons.star_outline, size: 16),
          label: Text('Write Review', style: GoogleFonts.poppins(fontSize: 12)),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: reviewService.hasUserReviewedBooking(booking.id),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 36);
        final hasReviewed = snap.data == true;
        reviewCache[booking.id] = hasReviewed;
        if (hasReviewed) {
          return Row(children: [
            const Icon(Icons.check_circle, size: 16, color: CAppTheme.successColor),
            const SizedBox(width: 6),
            Flexible(child: Text('Review submitted', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor, fontWeight: FontWeight.w600))),
          ]);
        }
        return SizedBox(
          height: 36,
          child: OutlinedButton.icon(
            onPressed: onReviewTap,
            icon: const Icon(Icons.star_outline, size: 16),
            label: Text('Write Review', style: GoogleFonts.poppins(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
        );
      },
    );
  }

  Widget _buildPaymentStatus() {
    if (payment == null) {
      return SizedBox(
        height: 36,
        child: ElevatedButton.icon(
          onPressed: onPayTap,
          icon: const Icon(Icons.payment, size: 16),
          label: Text('Pay Now', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: CAppTheme.warningColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      );
    }

    if (payment!.status == 'completed') {
      return Row(children: [
        const Icon(Icons.check_circle, size: 16, color: CAppTheme.successColor),
        const SizedBox(width: 6),
        Text('Payment Completed', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor, fontWeight: FontWeight.w600)),
      ]);
    }

    final isExpired = payment!.isExpired;
    return Row(
      children: [
        Icon(isExpired ? Icons.error : Icons.access_time, size: 16, color: isExpired ? CAppTheme.errorColor : CAppTheme.warningColor),
        const SizedBox(width: 6),
        Text(isExpired ? 'Payment Expired' : 'Payment Pending', style: GoogleFonts.poppins(fontSize: 12, color: isExpired ? CAppTheme.errorColor : CAppTheme.warningColor, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: onPayTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: isExpired ? CAppTheme.errorColor : CAppTheme.warningColor),
              foregroundColor: isExpired ? CAppTheme.errorColor : CAppTheme.warningColor,
            ),
            child: Text(isExpired ? 'Retry' : 'Pay', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
