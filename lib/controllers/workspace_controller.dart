import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/workspace_service.dart';

class WorkspaceController with ChangeNotifier {
  final WorkspaceService _service = WorkspaceService();
  final BookingService _bookingService = BookingService();

  List<WorkspaceModel> _workspaces = [];
  List<WorkspaceModel> _filteredWorkspaces = [];
  bool _isLoading = false;
  bool _isBooking = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<String> _selectedAmenities = [];
  String? _selectedCategory;
  final Map<String, List<BookingModel>> _dailyBookingsCache = {};

  List<WorkspaceModel> get workspaces {
    if (_searchQuery.isEmpty && _selectedAmenities.isEmpty && _selectedCategory == null) {
      return _workspaces;
    }
    return _filteredWorkspaces;
  }

  /// Raw list for owner dashboard — ignores user-side search/filters.
  List<WorkspaceModel> get ownerWorkspaces => _workspaces;
  
  bool get isLoading => _isLoading;
  bool get isBooking => _isBooking;
  String? get errorMessage => _errorMessage;
  List<String> get selectedAmenities => _selectedAmenities;
  String? get selectedCategory => _selectedCategory;

  /// Preset amenities plus custom ones from listed workspaces (for user filters).
  List<String> get filterAmenityOptions {
    final customByLower = <String, String>{};
    for (final ws in _workspaces) {
      for (final amenity in ws.amenities) {
        final trimmed = amenity.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        final isPreset = AppConstants.commonAmenities
            .any((c) => c.toLowerCase() == lower);
        if (isPreset) continue;
        customByLower.putIfAbsent(lower, () => trimmed);
      }
    }
    final custom = customByLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...AppConstants.commonAmenities, ...custom];
  }

  Future<void> loadWorkspaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _service.getAllWorkspaces();
      if (_searchQuery.isNotEmpty || _selectedAmenities.isNotEmpty || _selectedCategory != null) {
        _applyFilters();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<WorkspaceModel>> getWorkspacesStream() => _service.getAllWorkspacesStream();

  Stream<List<WorkspaceModel>> getOwnerWorkspacesStream(String ownerId) =>
      _service.getWorkspacesByOwnerIdStream(ownerId);

  /// Realtime sync without toggling the full-screen loading state.
  void applyOwnerWorkspacesFromStream(List<WorkspaceModel> workspaces) {
    _workspaces = workspaces;
    notifyListeners();
  }

  void _clearUserFilters() {
    _searchQuery = '';
    _selectedAmenities = [];
    _selectedCategory = null;
    _filteredWorkspaces = [];
  }

  Future<void> loadOwnerWorkspaces(String ownerId) async {
    _clearUserFilters();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _service.getWorkspacesByOwnerId(ownerId);
      if (_searchQuery.isNotEmpty || _selectedAmenities.isNotEmpty || _selectedCategory != null) {
        _applyFilters();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchWorkspaces(String query) {
    _searchQuery = query.trim();
    _applyFilters();
  }

  void filterByAmenities(List<String> amenities) {
    _selectedAmenities = amenities;
    _applyFilters();
  }

  void filterByCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty && _selectedAmenities.isEmpty && _selectedCategory == null) {
      _filteredWorkspaces = [];
    } else {
      _filteredWorkspaces = _workspaces.where((w) {
        final matchesSearch = _searchQuery.isEmpty ||
            w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.city.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.amenities.any(
              (a) => a.toLowerCase().contains(_searchQuery.toLowerCase()),
            );

        final matchesAmenities = _selectedAmenities.isEmpty ||
            _selectedAmenities.every((a) => w.amenities.map((e) => e.toLowerCase()).contains(a.toLowerCase()));

        final matchesCategory = _selectedCategory == null ||
            w.workspaceType.toLowerCase() == _selectedCategory!.toLowerCase() ||
            w.categoryOptions.any((cat) => cat.type.toLowerCase() == _selectedCategory!.toLowerCase());

        return matchesSearch && matchesAmenities && matchesCategory;
      }).toList();
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedAmenities = [];
    _selectedCategory = null;
    _filteredWorkspaces = [];
    notifyListeners();
  }

  Future<bool> createWorkspace(WorkspaceModel workspace) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.createWorkspace(workspace);
      await loadOwnerWorkspaces(workspace.ownerId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateWorkspace(WorkspaceModel workspace) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.updateWorkspace(workspace);
      await loadOwnerWorkspaces(workspace.ownerId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteWorkspace(String workspaceId, {String? ownerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteWorkspace(workspaceId);
      if (ownerId != null) {
        await loadOwnerWorkspaces(ownerId);
      } else {
        await loadWorkspaces();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<WorkspaceModel?> getWorkspaceById(String id) async {
    try {
      return await _service.getWorkspaceById(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _buildDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<List<BookingModel>> getBookingsForWorkspaceDate(String workspaceId, DateTime date) async {
    final cacheKey = '$workspaceId-${_buildDateKey(date)}';
    if (_dailyBookingsCache.containsKey(cacheKey)) {
      return _dailyBookingsCache[cacheKey]!;
    }

    try {
      final bookings = await _bookingService.getBookingsByWorkspaceAndDate(workspaceId, _buildDateKey(date));
      _dailyBookingsCache[cacheKey] = bookings;
      return bookings;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> bookWorkspaceTimeslot({
    required BookingModel booking,
    required WorkspaceModel workspace,
  }) async {
    _isBooking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _bookingService.createBooking(booking);
      final cacheKey = '${workspace.id}-${booking.bookingDateKey}';
      _dailyBookingsCache.remove(cacheKey);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }
}
