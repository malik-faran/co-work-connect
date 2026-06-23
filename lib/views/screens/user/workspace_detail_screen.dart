import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/services/review_service.dart';
import 'package:cwc/models/review_model.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';
import 'package:cwc/views/screens/payment/payment_screen.dart';
import 'package:cwc/views/widgets/location_picker_map.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkspaceDetailScreen extends StatefulWidget {
  final String workspaceId;
  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  WorkspaceModel? _workspace;
  bool _isLoading = true;
  bool _isSlotsLoading = false;
  int _currentImageIndex = 0;
  WorkspaceCategoryOption? _selectedCategory;
  List<WorkspaceTimeSlotTemplate> _selectedSlots = [];
  List<String> _selectedSlotIds = [];
  int _selectedSeats = 1;
  // Booking mode: 'hourly' | 'daily' | 'monthly'
  String _bookingMode = 'hourly';
  int _monthCount = 1;
  DateTime _selectedDate = DateTime.now();

  bool get _isPerDayBooking => _bookingMode == 'daily';
  bool get _isMonthlyBooking => _bookingMode == 'monthly';

  /// Monthly rate derived from the daily price (30 days per month).
  double get _monthlyRate =>
      (_selectedCategory?.pricePerDay ?? 0) * 30;
  Map<String, Map<String, int>> _slotSeatUsage = {};
  final PageController _pageController = PageController();
  final ReviewService _reviewService = ReviewService();
  List<ReviewModel> _reviews = [];
  BookingModel? _lastBooking;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    final controller = context.read<WorkspaceController>();
    final workspace = await controller.getWorkspaceById(widget.workspaceId);
    setState(() {
      _workspace = workspace;
      _selectedCategory = _getInitialCategory(workspace);
      _isLoading = false;
    });
    await _loadAvailability();
    await _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getWorkspaceReviews(widget.workspaceId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {}
  }

  Future<void> _openInExternalMaps() async {
    if (_workspace == null) return;
    final lat = _workspace!.latitude;
    final lng = _workspace!.longitude;
    final label = Uri.encodeComponent(_workspace!.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  WorkspaceCategoryOption? _getInitialCategory(WorkspaceModel? workspace) {
    if (workspace == null) return null;
    if (workspace.categoryOptions.isNotEmpty) return workspace.categoryOptions.first;
    return WorkspaceCategoryOption(
      type: workspace.workspaceType,
      capacity: workspace.capacity > 0 ? workspace.capacity : 10,
      pricePerHour: workspace.pricePerHour > 0 ? workspace.pricePerHour : workspace.pricePerDay / 8,
      pricePerDay: workspace.pricePerDay,
    );
  }

  Future<void> _loadAvailability() async {
    if (_workspace == null) return;
    setState(() => _isSlotsLoading = true);
    try {
      final bookings = await context.read<WorkspaceController>().getBookingsForWorkspaceDate(_workspace!.id, _selectedDate);
      final usage = <String, Map<String, int>>{};
      for (final b in bookings) {
        if (b.timeSlotId != null && b.categoryType != null) {
          usage.putIfAbsent(b.timeSlotId!, () => {});
          usage[b.timeSlotId!]![b.categoryType!] = (usage[b.timeSlotId!]![b.categoryType!] ?? 0) + b.seatCount;
        }
      }
      if (mounted) setState(() => _slotSeatUsage = usage);
    } finally {
      if (mounted) setState(() => _isSlotsLoading = false);
    }
  }

  List<DateTime> get _upcomingDates => List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  List<WorkspaceTimeSlotTemplate> get timeSlots =>
      _workspace?.timeSlots.isEmpty ?? true ? _generateTimeSlotsFromHours() : _workspace!.timeSlots;

  List<WorkspaceTimeSlotTemplate> _generateTimeSlotsFromHours() {
    if (_workspace == null) return [];
    final open = _workspace!.openingTime.split(':');
    final close = _workspace!.closingTime.split(':');
    if (open.length != 2 || close.length != 2) return [];
    final s = int.tryParse(open[0]) ?? 9;
    final e = int.tryParse(close[0]) ?? 18;
    return List.generate(e - s, (i) {
      final h = s + i;
      return WorkspaceTimeSlotTemplate(
        id: 'slot_${h}_${h + 1}',
        label: '${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00',
        startHour: h, endHour: h + 1,
      );
    });
  }

  String _categoryLabel(String type) {
    switch (type) {
      case AppConstants.workspaceTypePrivate: return 'Private Office';
      case AppConstants.workspaceTypeMeetingRoom: return 'Meeting Room';
      default: return 'Shared Desk';
    }
  }

  int _availableSeatsForSlot(WorkspaceTimeSlotTemplate slot) {
    if (_selectedCategory == null) return 0;
    final booked = _slotSeatUsage[slot.id]?[_selectedCategory!.type] ?? 0;
    final selected = _selectedSlotIds.contains(slot.id) ? _selectedSeats : 0;
    return (_selectedCategory!.capacity - booked - selected).clamp(0, double.infinity).toInt();
  }

  Future<void> _handleBooking() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) { _msg('Please login to book a workspace', true); return; }
    if (_selectedCategory == null) { _msg('Select a category to continue', true); return; }

    final controller = context.read<WorkspaceController>();
    bool ok;

    if (_isMonthlyBooking) {
      ok = await _bookMonthly(user, controller);
    } else if (_isPerDayBooking) {
      ok = await _bookFullDay(user, controller);
    } else {
      if (_selectedSlots.isEmpty) { _msg('Select at least one time slot', true); return; }
      ok = await _bookTimeSlots(user, controller);
    }

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(booking: _lastBooking!))).then((paymentSuccess) {
        if (paymentSuccess == true) _msg('Booking confirmed! Payment successful.', false);
      });
      setState(() { _selectedSlots.clear(); _selectedSlotIds.clear(); _bookingMode = 'hourly'; _monthCount = 1; });
      await _loadAvailability();
    } else {
      _msg(controller.errorMessage ?? 'Failed to create booking.', true);
    }
  }

  Future<bool> _bookMonthly(user, WorkspaceController controller) async {
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final days = 30 * _monthCount;
    final end = start.add(Duration(days: days));
    final price = _monthlyRate * _monthCount;
    final booking = BookingModel(
      id: const Uuid().v4(), userId: user.id, workspaceId: _workspace!.id,
      workspaceName: _workspace!.name, startDate: start, endDate: end,
      numberOfDays: days, durationHours: 24 * days, totalPrice: price,
      status: AppConstants.bookingStatusPending, createdAt: DateTime.now(), isHourlyBooking: false,
      bookingDateKey: DateFormat('yyyy-MM-dd').format(_selectedDate), categoryType: _selectedCategory!.type,
      seatCount: 1, pricePerDay: _selectedCategory!.pricePerDay, pricePerHour: _selectedCategory!.pricePerHour);
    setState(() => _lastBooking = booking);
    return await controller.bookWorkspaceTimeslot(booking: booking, workspace: _workspace!);
  }

  Future<bool> _bookFullDay(user, WorkspaceController controller) async {
    final booking = _createBooking(userId: user.id,
      startDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      endDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59),
      durationHours: 24, totalPrice: _selectedCategory!.pricePerDay, isHourlyBooking: false, seatCount: 1);
    setState(() => _lastBooking = booking);
    return await controller.bookWorkspaceTimeslot(booking: booking, workspace: _workspace!);
  }

  Future<bool> _bookTimeSlots(user, WorkspaceController controller) async {
    for (var slot in _selectedSlots) {
      if (_availableSeatsForSlot(slot) < _selectedSeats) {
        _msg('Slot ${slot.label} does not have enough seats', true);
        return false;
      }
    }
    bool ok = true;
    for (var slot in _selectedSlots) {
      final dur = slot.endHour - slot.startHour;
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, slot.startHour);
      final booking = _createBooking(userId: user.id, startDate: start, endDate: start.add(Duration(hours: dur)),
        durationHours: dur, totalPrice: _selectedCategory!.pricePerHour * dur * _selectedSeats,
        isHourlyBooking: true, seatCount: _selectedSeats, timeSlotId: slot.id, timeSlotLabel: slot.label);
      _lastBooking ??= booking;
      if (!await controller.bookWorkspaceTimeslot(booking: booking, workspace: _workspace!)) ok = false;
    }
    return ok;
  }

  BookingModel _createBooking({required String userId, required DateTime startDate, required DateTime endDate,
    required int durationHours, required double totalPrice, required bool isHourlyBooking,
    required int seatCount, String? timeSlotId, String? timeSlotLabel}) {
    return BookingModel(id: const Uuid().v4(), userId: userId, workspaceId: _workspace!.id,
      workspaceName: _workspace!.name, startDate: startDate, endDate: endDate,
      numberOfDays: isHourlyBooking ? 0 : 1, durationHours: durationHours, totalPrice: totalPrice,
      status: AppConstants.bookingStatusPending, createdAt: DateTime.now(), isHourlyBooking: isHourlyBooking,
      bookingDateKey: DateFormat('yyyy-MM-dd').format(_selectedDate), categoryType: _selectedCategory!.type,
      seatCount: seatCount, pricePerDay: _selectedCategory!.pricePerDay, pricePerHour: _selectedCategory!.pricePerHour,
      timeSlotId: timeSlotId, timeSlotLabel: timeSlotLabel);
  }

  void _msg(String text, bool isError) {
    if (!mounted) return;
    isError ? showErrorSnackBar(context, text) : showSuccessSnackBar(context, text);
  }

  Future<void> _startChatWithOwner() async {
    try {
      final user = context.read<AuthController>().currentUser;
      if (user == null || _workspace == null) return;
      final ownerData = await SupabaseService.client.from('users')
          .select('id, name, email, profile_image_url').eq('id', _workspace!.ownerId).maybeSingle();
      if (ownerData == null) { _msg('Owner not found', true); return; }
      final chatRoom = await ChatService().getOrCreateChatRoom(user1Id: user.id, user2Id: ownerData['id'], workspaceId: _workspace!.id);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatRoomId: chatRoom.id)));
    } catch (e) {
      _msg('Error starting chat: $e', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_workspace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workspace')),
        body: const Center(child: Text('Workspace not found')),
      );
    }

    final isBooking = context.watch<WorkspaceController>().isBooking;

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildDualBottomBar(isBooking),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: CAppTheme.primaryColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: _ImageCarousel(
          imageUrls: _workspace!.imageUrls,
          workspaceId: _workspace!.id,
          pageController: _pageController,
          currentIndex: _currentImageIndex,
          onPageChanged: (i) { if (mounted) setState(() => _currentImageIndex = i); },
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      transform: Matrix4.translationValues(0, -24, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(_workspace!.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: CAppTheme.textPrimary)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rs. ${_workspace!.pricePerDay.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor)),
                    Text('/day', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _InfoChip(icon: Icons.schedule_outlined, label: '${_workspace!.openingTime} - ${_workspace!.closingTime}'),
                  const SizedBox(width: 10),
                  _InfoChip(icon: Icons.star, label: '${(_workspace!.rating ?? 0.0).toStringAsFixed(1)} (${_workspace!.totalReviews})', iconColor: Colors.amber),
                  const SizedBox(width: 10),
                  if (_selectedCategory != null)
                    _InfoChip(icon: Icons.event_seat_outlined, label: '${_selectedCategory!.capacity} seats'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: CAppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [_workspace!.address, _workspace!.city, _workspace!.state, _workspace!.country].where((e) => e != null && e.isNotEmpty).join(', '),
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_workspace!.latitude != 0 || _workspace!.longitude != 0) ...[
              const SizedBox(height: 12),
              WorkspaceMapView(
                latitude: _workspace!.latitude,
                longitude: _workspace!.longitude,
                label: _workspace!.name,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openInExternalMaps,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: Text(
                    'Open in Maps',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Description
            Text('Description', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(_workspace!.description, style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.6)),
            const SizedBox(height: 20),

            // Amenities
            Text('Amenities', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _workspace!.amenities.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: CAppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(a, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: CAppTheme.primaryColor)),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),

            // Reviews
            _buildReviewsSection(),
            const SizedBox(height: 20),

            // Category selector
            _buildCategorySection(),
            const SizedBox(height: 20),

            // Date selector
            _buildDateSelector(),
            const SizedBox(height: 20),

            // Booking mode (Hourly / Daily / Monthly)
            if (_selectedCategory != null) _buildBookingModeSelector(),
            const SizedBox(height: 16),

            // Time slots (hourly only)
            if (_bookingMode == 'hourly') _buildTimeSlotsSection(),
            if (_isMonthlyBooking && _selectedCategory != null) _buildMonthCountSelector(),
            const SizedBox(height: 12),
            if (_selectedSlots.isNotEmpty && _bookingMode == 'hourly' && _selectedCategory != null) _buildSeatSelector(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final avg = _workspace?.rating ?? 0.0;
    final total = _workspace?.totalReviews ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reviews ($total)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
            if (total > 0) Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(avg.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: CAppTheme.textPrimary)),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No reviews yet', style: GoogleFonts.poppins(color: CAppTheme.textTertiary)),
          ))
        else
          ..._reviews.take(3).map((r) => _ReviewCard(review: r)),
        if (_reviews.length > 3)
          Center(child: TextButton(onPressed: () {}, child: Text('See all ${_reviews.length} reviews'))),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workspace Type', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
        const SizedBox(height: 10),
        if (_workspace!.categoryOptions.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CAppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              border: Border.all(color: CAppTheme.warningColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: CAppTheme.warningColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('No categories configured. Contact the owner.', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary))),
            ]),
          ),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: (_workspace!.categoryOptions.isEmpty && _selectedCategory != null
              ? [_selectedCategory!]
              : _workspace!.categoryOptions
          ).map((cat) {
            final on = _selectedCategory?.type == cat.type;
            return GestureDetector(
              onTap: () {
                setState(() { _selectedCategory = cat; _selectedSeats = 1; _selectedSlots.clear(); _selectedSlotIds.clear(); });
                _loadAvailability();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: on ? CAppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  border: Border.all(color: on ? CAppTheme.primaryColor : CAppTheme.borderColor),
                  boxShadow: on ? CAppTheme.cardShadow : null,
                ),
                child: Column(
                  children: [
                    Text(_categoryLabel(cat.type), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : CAppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('${cat.capacity} seats', style: GoogleFonts.poppins(fontSize: 11, color: on ? Colors.white70 : CAppTheme.textTertiary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Date', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingDates.length,
            itemBuilder: (ctx, i) {
              final date = _upcomingDates[i];
              final on = DateUtils.isSameDay(date, _selectedDate);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () async { setState(() => _selectedDate = date); await _loadAvailability(); },
                  child: Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: on ? CAppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      border: on ? null : Border.all(color: CAppTheme.borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat.E().format(date), style: GoogleFonts.poppins(fontSize: 12, color: on ? Colors.white70 : CAppTheme.textTertiary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(DateFormat.d().format(date), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: on ? Colors.white : CAppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Slots', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
        const SizedBox(height: 10),
        if (timeSlots.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text('No slots available. Book full day.', style: GoogleFonts.poppins(color: CAppTheme.textTertiary)))
        else if (_isSlotsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: timeSlots.map((slot) {
              final on = _selectedSlotIds.contains(slot.id);
              final avail = _availableSeatsForSlot(slot);
              final full = avail <= 0;
              return GestureDetector(
                onTap: full ? null : () => _handleSlotTap(slot),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: on ? CAppTheme.primaryColor : full ? CAppTheme.borderColor : Colors.white,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    border: Border.all(color: on ? CAppTheme.primaryColor : CAppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(slot.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: on ? Colors.white : full ? CAppTheme.textTertiary : CAppTheme.textPrimary), textAlign: TextAlign.center),
                      if (on) const Icon(Icons.check_circle, size: 14, color: Colors.white),
                      if (!on && !full && _selectedCategory != null)
                        Text('$avail seats', style: GoogleFonts.poppins(fontSize: 10, color: CAppTheme.textTertiary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _handleSlotTap(WorkspaceTimeSlotTemplate slot) {
    if (_selectedCategory == null) { _msg('Select a category first', true); return; }
    if (_availableSeatsForSlot(slot) <= 0) return;
    setState(() {
      if (_selectedSlotIds.contains(slot.id)) { _selectedSlotIds.remove(slot.id); _selectedSlots.removeWhere((s) => s.id == slot.id); }
      else { _selectedSlotIds.add(slot.id); _selectedSlots.add(slot); }
      if (_selectedSlots.isEmpty) _selectedSeats = 1;
    });
  }

  Widget _buildBookingModeSelector() {
    final modes = [
      ('hourly', 'Hourly', Icons.schedule_rounded,
          'Rs. ${_selectedCategory!.pricePerHour.toStringAsFixed(0)}/hr'),
      ('daily', 'Daily', Icons.today_rounded,
          'Rs. ${_selectedCategory!.pricePerDay.toStringAsFixed(0)}/day'),
      ('monthly', 'Monthly', Icons.calendar_month_rounded,
          'Rs. ${_monthlyRate.toStringAsFixed(0)}/mo'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking Plan',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: modes.map((m) {
            final on = _bookingMode == m.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _bookingMode = m.$1;
                    if (m.$1 != 'hourly') {
                      _selectedSlots.clear();
                      _selectedSlotIds.clear();
                      _selectedSeats = 1;
                    }
                    if (m.$1 != 'monthly') _monthCount = 1;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: on ? CAppTheme.primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      border: Border.all(color: on ? CAppTheme.primaryColor : CAppTheme.borderColor),
                      boxShadow: on ? CAppTheme.cardShadow : null,
                    ),
                    child: Column(
                      children: [
                        Icon(m.$3, size: 20, color: on ? Colors.white : CAppTheme.primaryColor),
                        const SizedBox(height: 6),
                        Text(m.$2,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: on ? Colors.white : CAppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        FittedBox(
                          child: Text(m.$4,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: on ? Colors.white70 : CAppTheme.textTertiary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMonthCountSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(color: CAppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number of months',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('Starts ${DateFormat.yMMMd().format(_selectedDate)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: CAppTheme.textSecondary)),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _monthCount > 1 ? () => setState(() => _monthCount--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: CAppTheme.primaryColor,
              ),
              Text('$_monthCount',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: _monthCount < 12 ? () => setState(() => _monthCount++) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: CAppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Seats', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: CAppTheme.borderColor), borderRadius: BorderRadius.circular(CAppTheme.radiusSmall)),
          child: DropdownButton<int>(
            value: _selectedSeats,
            underline: const SizedBox(),
            isDense: true,
            onChanged: (v) { if (v != null) setState(() => _selectedSeats = v); },
            items: List.generate(
              _selectedSlots.isEmpty ? 1 : _selectedSlots.map((s) => _availableSeatsForSlot(s)).reduce((a, b) => a < b ? a : b).clamp(1, 100),
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDualBottomBar(bool isBooking) {
    final canBook = (_selectedSlots.isNotEmpty || _isPerDayBooking || _isMonthlyBooking) && _selectedCategory != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canBook) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat.yMMMd().format(_selectedDate), style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
                  Text(
                    _isMonthlyBooking
                        ? 'Rs. ${(_monthlyRate * _monthCount).toStringAsFixed(0)}'
                        : _isPerDayBooking
                            ? 'Rs. ${_selectedCategory!.pricePerDay.toStringAsFixed(0)}'
                            : 'Rs. ${_selectedSlots.fold<double>(0.0, (s, slot) => s + (_selectedCategory!.pricePerHour * (slot.endHour - slot.startHour) * _selectedSeats)).toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startChatWithOwner,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('Contact', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusMedium)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: !canBook ? null : (isBooking ? null : _handleBooking),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusMedium)),
                    ),
                    child: isBooking
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            _isMonthlyBooking
                                ? 'Book $_monthCount Month${_monthCount > 1 ? 's' : ''}'
                                : !canBook
                                    ? 'Select slots'
                                    : _isPerDayBooking
                                        ? 'Book Full Day'
                                        : 'Book ${_selectedSlots.length} Slot(s)',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _InfoChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? CAppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: CAppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  final List<String> imageUrls;
  final String workspaceId;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageCarousel({required this.imageUrls, required this.workspaceId, required this.pageController, required this.currentIndex, required this.onPageChanged});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrls.isNotEmpty)
          PageView.builder(
            controller: pageController, itemCount: imageUrls.length, onPageChanged: onPageChanged,
            itemBuilder: (_, i) => Hero(
              tag: 'workspace_image_${workspaceId}_$i',
              child: Image.network(imageUrls[i], fit: BoxFit.cover,
                cacheWidth: kIsWeb ? 600 : 1200,
                loadingBuilder: (_, c, p) => p == null ? c : Container(color: CAppTheme.borderColor, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(color: CAppTheme.borderColor, child: const Icon(Icons.image_not_supported_outlined, size: 48, color: CAppTheme.textTertiary)),
              ),
            ),
          )
        else
          Container(color: CAppTheme.borderColor, child: const Icon(Icons.workspaces_outlined, size: 64, color: CAppTheme.textTertiary)),
        // Gradient overlay
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 80, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)]))),
        ),
        if (imageUrls.length > 1) Positioned(
          bottom: 16, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(imageUrls.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: currentIndex == i ? 24 : 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: currentIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.4)),
            )),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: review.userProfileImage != null ? NetworkImage(review.userProfileImage!) : null,
              child: review.userProfileImage == null
                  ? Text(safeInitial(review.userName), style: GoogleFonts.poppins(color: CAppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.userName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                Row(children: List.generate(5, (i) => Icon(i < review.rating.floor() ? Icons.star : Icons.star_border, size: 14, color: Colors.amber))),
              ],
            )),
            Text(_timeAgo(review.createdAt), style: GoogleFonts.poppins(fontSize: 11, color: CAppTheme.textTertiary)),
          ]),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary, height: 1.4)),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 30) return '${d.day}/${d.month}/${d.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}
