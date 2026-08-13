import 'package:flutter/material.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/services/workspace_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/views/screens/owner/owner_receipts_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class OwnerBookingsScreen extends StatefulWidget {
  /// When embedded in [OwnerHomeScreen] IndexedStack, only the visible tab
  /// should expose its FAB (avoids duplicate default hero tags).
  final bool showFab;

  /// When opened from a notification, highlight this booking in the list.
  final String? initialBookingId;

  /// 0 = All Bookings, 1 = Receipts (e.g. payment receipt notification).
  final int? initialTabIndex;

  const OwnerBookingsScreen({
    super.key,
    this.showFab = true,
    this.initialBookingId,
    this.initialTabIndex,
  });

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen>
    with SingleTickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();
  final PaymentService _paymentService = PaymentService();
  final Map<String, UserModel?> _userCache = {};
  final Map<String, PaymentModel?> _paymentCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final tab = widget.initialTabIndex;
    if (tab != null && tab >= 0 && tab < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(tab);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await _bookingService.updateBookingStatus(bookingId, status);
      
      if (mounted) {
        setState(() {});
        showSuccessSnackBar(context, 'Booking $status successfully');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error updating booking: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.bookingStatusConfirmed:
        return CAppTheme.successColor;
      case AppConstants.bookingStatusPending:
        return CAppTheme.warningColor;
      case AppConstants.bookingStatusCancelled:
        return CAppTheme.errorColor;
      default:
        return CAppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context, listen: false);
    final ownerId = authController.currentUser?.id;

    if (ownerId == null) {
      return Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        body: Center(
          child: Text(
            'Please login',
            style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      floatingActionButton: widget.showFab && _tabController.index == 0
          ? FloatingActionButton.extended(
        heroTag: 'owner_bookings_reserve_seat_fab',
        onPressed: () => _showManualBookingDialog(context, ownerId),
        backgroundColor: CAppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Reserve Seat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Bookings', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: CAppTheme.primaryColor,
          unselectedLabelColor: CAppTheme.textSecondary,
          indicatorColor: CAppTheme.primaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All Bookings'),
            Tab(text: 'Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsList(ownerId),
          const OwnerReceiptsScreen(),
        ],
      ),
    );
  }

  Widget _buildBookingsList(String ownerId) {
    return StreamBuilder<List<BookingModel>>(
        stream: _bookingService.getOwnerBookingsStream(ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: CAppTheme.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CAppTheme.errorColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: CAppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading bookings',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {}),
                    icon: Icon(Icons.refresh_rounded, color: CAppTheme.primaryColor),
                    label: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        color: CAppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          var bookings = snapshot.data ?? [];
          _paymentCache.clear();

          final focusId = widget.initialBookingId;
          if (focusId != null) {
            bookings = List<BookingModel>.from(bookings)
              ..sort((a, b) {
                if (a.id == focusId) return -1;
                if (b.id == focusId) return 1;
                return 0;
              });
          }

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      size: 48,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No bookings yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bookings will appear here once users start booking',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: CAppTheme.primaryColor,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return FutureBuilder<UserModel?>(
                  future: _getUserInfo(booking.userId),
                  builder: (context, userSnapshot) {
                    final user = userSnapshot.data;
                    final statusColor = _getStatusColor(booking.status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                        boxShadow: CAppTheme.softShadow,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: booking.id == focusId,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                            ),
                            child: Icon(
                              Icons.book_rounded,
                              color: CAppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            booking.workspaceName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: CAppTheme.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${_formatDate(booking.startDate)} - ${_formatDate(booking.endDate)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: CAppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${booking.numberOfDays} days • Rs. ${booking.totalPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: CAppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              _updateBookingStatus(booking.id, value);
                            },
                            itemBuilder: (context) => [
                              if (booking.status == AppConstants.bookingStatusPending)
                                PopupMenuItem(
                                  value: AppConstants.bookingStatusConfirmed,
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: CAppTheme.successColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Confirm', style: GoogleFonts.poppins()),
                                    ],
                                  ),
                                ),
                              if (booking.status == AppConstants.bookingStatusPending)
                                PopupMenuItem(
                                  value: AppConstants.bookingStatusCancelled,
                                  child: Row(
                                    children: [
                                      Icon(Icons.cancel_outlined, color: CAppTheme.errorColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Cancel', style: GoogleFonts.poppins()),
                                    ],
                                  ),
                                ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                              ),
                              child: Text(
                                booking.status.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          children: [
                            if (user != null)
                              Container(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CAppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User Information',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: CAppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(Icons.person_outline, 'Name', user.name),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.email_outlined, 'Email', user.email),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.phone_outlined, 'Phone', user.phone),
                                    if (booking.timeSlotLabel != null) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow(Icons.schedule_outlined, 'Time Slot', booking.timeSlotLabel!),
                                    ],
                                    if (booking.seatCount > 1) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow(Icons.chair_outlined, 'Seats', booking.seatCount.toString()),
                                    ],
                                    const SizedBox(height: 12),
                                    FutureBuilder<PaymentModel?>(
                                      future: _getPaymentInfo(booking.id),
                                      builder: (context, paymentSnapshot) {
                                        final payment = paymentSnapshot.data;

                                        Color payStatusColor;
                                        String statusText;

                                        if (payment != null) {
                                          if (payment.isAwaitingReceiptReview) {
                                            payStatusColor = CAppTheme.warningColor;
                                            statusText = 'Receipt pending review';
                                          } else if (payment.status == 'completed') {
                                            payStatusColor = CAppTheme.successColor;
                                            statusText = payment.isManual ? 'Paid (verified)' : 'Paid';
                                          } else if (payment.isManual && payment.isReceiptRejected) {
                                            payStatusColor = CAppTheme.errorColor;
                                            statusText = 'Receipt rejected';
                                          } else if (payment.status == 'pending') {
                                            payStatusColor = CAppTheme.warningColor;
                                            statusText = payment.isManual
                                                ? 'Awaiting transfer'
                                                : payment.status.toUpperCase();
                                          } else {
                                            payStatusColor = CAppTheme.errorColor;
                                            statusText = payment.status.toUpperCase();
                                          }
                                        } else if (booking.status == 'confirmed') {
                                          payStatusColor = CAppTheme.successColor;
                                          statusText = 'Paid';
                                        } else {
                                          payStatusColor = CAppTheme.warningColor;
                                          statusText = 'Not paid yet';
                                        }

                                        return Row(
                                          children: [
                                            Icon(Icons.payment_outlined, size: 18, color: payStatusColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Payment: ',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: CAppTheme.textSecondary,
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                statusText,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: payStatusColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: CAppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
    );
  }

  Future<UserModel?> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    try {
      final user = await _authService.getUserById(userId);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<PaymentModel?> _getPaymentInfo(String bookingId) async {
    if (_paymentCache.containsKey(bookingId)) {
      return _paymentCache[bookingId];
    }
    try {
      final payment = await _paymentService.getPaymentByBookingId(bookingId);
      _paymentCache[bookingId] = payment;
      return payment;
    } catch (e) {
      return null;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CAppTheme.textTertiary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CAppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: CAppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  List<WorkspaceTimeSlotTemplate> _getTimeSlotsForWorkspace(WorkspaceModel workspace) {
    if (workspace.timeSlots.isNotEmpty) return workspace.timeSlots;
    final open = workspace.openingTime.split(':');
    final close = workspace.closingTime.split(':');
    final s = int.tryParse(open[0]) ?? 9;
    final e = int.tryParse(close[0]) ?? 18;
    if (e <= s) return [];
    return List.generate(e - s, (i) {
      final h = s + i;
      return WorkspaceTimeSlotTemplate(
        id: 'slot_${h}_${h + 1}',
        label: '${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00',
        startHour: h,
        endHour: h + 1,
      );
    });
  }

  Future<Map<String, Map<String, int>>> _loadSlotUsage(String workspaceId, DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final bookings = await _bookingService.getBookingsByWorkspaceAndDate(workspaceId, dateKey);
    final usage = <String, Map<String, int>>{};
    for (final b in bookings) {
      if (b.timeSlotId != null && b.categoryType != null) {
        usage.putIfAbsent(b.timeSlotId!, () => {});
        usage[b.timeSlotId!]![b.categoryType!] = (usage[b.timeSlotId!]![b.categoryType!] ?? 0) + b.seatCount;
      }
    }
    return usage;
  }

  Future<void> _showManualBookingDialog(BuildContext context, String ownerId) async {
    final ownerName = context.read<AuthController>().currentUser?.name ?? 'Owner';
    final workspaceService = WorkspaceService();
    final notificationService = NotificationService();
    final workspaces = await workspaceService.getWorkspacesByOwnerId(ownerId);
    
    if (!context.mounted) return;
    if (workspaces.isEmpty) {
      showErrorSnackBar(context, 'No workspaces available. Please add a workspace first.');
      return;
    }

    WorkspaceModel? selectedWorkspace;
    WorkspaceCategoryOption? selectedCategory;
    DateTime? selectedDate;
    WorkspaceTimeSlotTemplate? selectedSlot;
    int seatCount = 1;
    int maxSeats = 1;
    bool isLoading = false;
    bool isLoadingSlots = false;
    final userEmailController = TextEditingController();

    List<WorkspaceTimeSlotTemplate> availableSlots = [];
    Map<String, Map<String, int>> slotUsage = {};

    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {

          int getAvailableSeats(WorkspaceTimeSlotTemplate slot) {
            if (selectedCategory == null) return 0;
            final booked = slotUsage[slot.id]?[selectedCategory!.type] ?? 0;
            return (selectedCategory!.capacity - booked).clamp(0, selectedCategory!.capacity);
          }

          Future<void> reloadSlots() async {
            if (selectedWorkspace == null || selectedDate == null) return;
            setDialogState(() => isLoadingSlots = true);
            slotUsage = await _loadSlotUsage(selectedWorkspace!.id, selectedDate!);
            setDialogState(() {
              isLoadingSlots = false;
              selectedSlot = null;
              seatCount = 1;
              maxSeats = 1;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: Icon(Icons.event_seat_rounded, color: CAppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reserve Seat',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: CAppTheme.textPrimary, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Workspace selector
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration('Select Workspace'),
                      isExpanded: true,
                      items: workspaces.map((w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(w.name, style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) {
                        final ws = workspaces.firstWhere((w) => w.id == value);
                        setDialogState(() {
                          selectedWorkspace = ws;
                          selectedCategory = null;
                          selectedSlot = null;
                          availableSlots = _getTimeSlotsForWorkspace(ws);
                          slotUsage = {};
                          seatCount = 1;
                          maxSeats = 1;
                        });
                        if (selectedDate != null) reloadSlots();
                      },
                    ),
                    const SizedBox(height: 14),

                    // User email
                    TextField(
                      controller: userEmailController,
                      style: GoogleFonts.poppins(color: CAppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDecoration('User Email'),
                    ),
                    const SizedBox(height: 14),

                    // Category selector (shown after workspace selected)
                    if (selectedWorkspace != null && selectedWorkspace!.categoryOptions.isNotEmpty) ...[
                      Text('Category', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: selectedWorkspace!.categoryOptions.map((cat) {
                          final selected = selectedCategory?.type == cat.type;
                          return ChoiceChip(
                            label: Text(
                              '${cat.type} (${cat.capacity})',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : CAppTheme.textPrimary,
                              ),
                            ),
                            selected: selected,
                            selectedColor: CAppTheme.primaryColor,
                            backgroundColor: CAppTheme.backgroundColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusMedium)),
                            onSelected: (_) {
                              setDialogState(() {
                                selectedCategory = cat;
                                selectedSlot = null;
                                seatCount = 1;
                                maxSeats = 1;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Date selector
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedDate = date;
                            selectedSlot = null;
                            seatCount = 1;
                          });
                          await reloadSlots();
                        }
                      },
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      child: InputDecorator(
                        decoration: _inputDecoration('Select Date').copyWith(
                          suffixIcon: Icon(Icons.calendar_today_rounded, color: CAppTheme.primaryColor, size: 20),
                        ),
                        child: Text(
                          selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate!) : 'Select Date',
                          style: GoogleFonts.poppins(
                            color: selectedDate != null ? CAppTheme.textPrimary : CAppTheme.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Time slots (shown after workspace + date selected)
                    if (selectedWorkspace != null && selectedDate != null && selectedCategory != null) ...[
                      Text('Available Slots', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      if (isLoadingSlots)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        ))
                      else if (availableSlots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No slots configured for this workspace', style: GoogleFonts.poppins(color: CAppTheme.textTertiary, fontSize: 13)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: availableSlots.map((slot) {
                            final avail = getAvailableSeats(slot);
                            final isSelected = selectedSlot?.id == slot.id;
                            final isFull = avail <= 0;
                            return GestureDetector(
                              onTap: isFull ? null : () {
                                setDialogState(() {
                                  selectedSlot = slot;
                                  maxSeats = avail;
                                  seatCount = seatCount.clamp(1, avail);
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isFull
                                      ? CAppTheme.errorColor.withValues(alpha: 0.08)
                                      : isSelected
                                          ? CAppTheme.primaryColor
                                          : CAppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                                  border: Border.all(
                                    color: isFull
                                        ? CAppTheme.errorColor.withValues(alpha: 0.3)
                                        : isSelected
                                            ? CAppTheme.primaryColor
                                            : CAppTheme.borderColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      slot.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isFull
                                            ? CAppTheme.errorColor.withValues(alpha: 0.5)
                                            : isSelected ? Colors.white : CAppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFull ? 'Full' : '$avail left',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isFull
                                            ? CAppTheme.errorColor.withValues(alpha: 0.6)
                                            : isSelected ? Colors.white70 : CAppTheme.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 14),
                    ],

                    // Seat count (shown after slot selected)
                    if (selectedSlot != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: CAppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            Text('Seats:', style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 14)),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: seatCount > 1 ? CAppTheme.primaryColor : CAppTheme.textTertiary, size: 22),
                              onPressed: seatCount > 1 ? () => setDialogState(() => seatCount--) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              '$seatCount',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: CAppTheme.primaryColor, fontSize: 18),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: seatCount < maxSeats ? CAppTheme.primaryColor : CAppTheme.textTertiary, size: 22),
                              onPressed: seatCount < maxSeats ? () => setDialogState(() => seatCount++) : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              '/ $maxSeats',
                              style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Price summary
                      if (selectedCategory != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CAppTheme.primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                            border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: CAppTheme.textPrimary)),
                              Text(
                                'Rs. ${(selectedCategory!.pricePerHour * (selectedSlot!.endHour - selectedSlot!.startHour) * seatCount).toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: GoogleFonts.poppins(color: CAppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (selectedWorkspace == null || userEmailController.text.isEmpty || selectedDate == null || selectedSlot == null) {
                    showErrorSnackBar(dialogContext, 'Please fill all required fields and select a slot');
                    return;
                  }
                  if (selectedCategory == null) {
                    showErrorSnackBar(dialogContext, 'Please select a category');
                    return;
                  }

                  setDialogState(() => isLoading = true);

                  try {
                    final userData = await SupabaseService.client
                        .from('users')
                        .select('id, name')
                        .eq('email', userEmailController.text.trim())
                        .maybeSingle();

                    if (userData == null) {
                      setDialogState(() => isLoading = false);
                      if (dialogContext.mounted) showErrorSnackBar(dialogContext, 'User not found. Ask user to register first.');
                      return;
                    }

                    final userId = userData['id'] as String;
                    final userName = userData['name'] as String? ?? 'A user';
                    final dur = selectedSlot!.endHour - selectedSlot!.startHour;
                    final start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedSlot!.startHour);
                    final end = start.add(Duration(hours: dur));
                    final bookingId = const Uuid().v4();

                    final booking = BookingModel(
                      id: bookingId,
                      userId: userId,
                      workspaceId: selectedWorkspace!.id,
                      workspaceName: selectedWorkspace!.name,
                      startDate: start,
                      endDate: end,
                      numberOfDays: 1,
                      durationHours: dur,
                      totalPrice: selectedCategory!.pricePerHour * dur * seatCount,
                      status: AppConstants.bookingStatusConfirmed,
                      isHourlyBooking: true,
                      seatCount: seatCount,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      bookingDateKey: DateFormat('yyyy-MM-dd').format(selectedDate!),
                      timeSlotId: selectedSlot!.id,
                      timeSlotLabel: selectedSlot!.label,
                      categoryType: selectedCategory!.type,
                      pricePerHour: selectedCategory!.pricePerHour,
                      pricePerDay: selectedCategory!.pricePerDay,
                    );

                    await _bookingService.createBooking(booking);

                    // Send notification to the reserved user
                    try {
                      await notificationService.sendSeatReservedNotification(
                        userId: userId,
                        workspaceName: selectedWorkspace!.name,
                        bookingId: bookingId,
                        timeSlotLabel: selectedSlot!.label,
                        seatCount: seatCount,
                      );
                    } catch (_) {}

                    // Send chat message to the reserved user
                    try {
                      final chatService = ChatService();
                      final chatRoom = await chatService.getOrCreateChatRoom(
                        user1Id: ownerId,
                        user2Id: userId,
                        workspaceId: selectedWorkspace!.id,
                      );
                      await chatService.sendMessage(ChatMessageModel(
                        id: const Uuid().v4(),
                        chatRoomId: chatRoom.id,
                        senderId: ownerId,
                        senderName: ownerName,
                        message: 'Hi $userName! A seat has been reserved for you at "${selectedWorkspace!.name}" on ${DateFormat('MMM dd, yyyy').format(selectedDate!)} (${selectedSlot!.label}, $seatCount seat${seatCount > 1 ? 's' : ''}). See you there!',
                        createdAt: DateTime.now(),
                      ));
                    } catch (_) {}

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (mounted) {
                      setState(() {});
                      if (context.mounted) {
                        showSuccessSnackBar(context, 'Seat reserved for $userName successfully');
                      }
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    if (dialogContext.mounted) showErrorSnackBar(dialogContext, 'Error: ${e.toString()}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CAppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusMedium)),
                ),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Reserve', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        borderSide: BorderSide(color: CAppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        borderSide: BorderSide(color: CAppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        borderSide: BorderSide(color: CAppTheme.primaryColor, width: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
