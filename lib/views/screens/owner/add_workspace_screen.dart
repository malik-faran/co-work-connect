// Add Workspace Screen — allows owners to add a new workspace.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/price_suggestion.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/services/price_prediction_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/price_benchmarks.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/constants/validation_constants.dart';
import 'package:cwc/utils/helpers/geo_utils.dart';
import 'package:latlong2/latlong.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/form_validators.dart';
import 'package:cwc/models/location_pick_result.dart';
import 'package:cwc/views/widgets/location_picker_map.dart';

class AddWorkspaceScreen extends StatefulWidget {
  final WorkspaceModel? workspaceToEdit;

  const AddWorkspaceScreen({super.key, this.workspaceToEdit});

  @override
  State<AddWorkspaceScreen> createState() => _AddWorkspaceScreenState();
}

class _UnitImageData {
  final List<XFile> selectedImages = [];
  final List<String> existingImageUrls = [];
}

class _CategoryFormData {
  final String label;
  final String type;
  bool enabled = false;
  final TextEditingController noOfOfficesController;
  final TextEditingController desksPerRoomController;
  final TextEditingController pricePerDayController;
  final TextEditingController pricePerHourController;
  final List<_UnitImageData> unitImageBuckets = [_UnitImageData()];

  _CategoryFormData({required this.label, required this.type})
    : noOfOfficesController = TextEditingController(),
      desksPerRoomController = TextEditingController(),
      pricePerDayController = TextEditingController(),
      pricePerHourController = TextEditingController();

  void dispose() {
    noOfOfficesController.dispose();
    desksPerRoomController.dispose();
    pricePerDayController.dispose();
    pricePerHourController.dispose();
  }
}

class _AddWorkspaceScreenState extends State<AddWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final List<String> _selectedDescriptionItems = [];
  final List<String> _selectedPolicyItems = [];
  final TextEditingController _customDescriptionController = TextEditingController();
  final TextEditingController _customPolicyController = TextEditingController();

  String? _selectedCity;
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _locationSet = false;
  List<String> _selectedAmenities = [];
  final TextEditingController _customAmenityController = TextEditingController();
  bool _isAvailable = true;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final List<String> _existingGeneralImageUrls = [];
  XFile? _legalDocument;
  String? _existingLegalDocumentUrl;
  final Map<String, _CategoryFormData> _categoryForms = {
    AppConstants.workspaceTypePrivate: _CategoryFormData(
      label: 'Private Office',
      type: AppConstants.workspaceTypePrivate,
    ),
    AppConstants.workspaceTypeShared: _CategoryFormData(
      label: 'Shared Office',
      type: AppConstants.workspaceTypeShared,
    ),
    AppConstants.workspaceTypeMeetingRoom: _CategoryFormData(
      label: 'Meeting Room',
      type: AppConstants.workspaceTypeMeetingRoom,
    ),
  };
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 18, minute: 0);

  final PricePredictionService _pricePredictionService = PricePredictionService();
  final Map<String, PriceSuggestion?> _priceSuggestions = {};
  final Map<String, bool> _priceSuggestionLoading = {};
  Timer? _priceSuggestionDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.workspaceToEdit != null) {
      final workspace = widget.workspaceToEdit!;
      _nameController.text = workspace.name;
      _parseListedText(workspace.description, _selectedDescriptionItems);
      _parseListedText(workspace.officePolicies, _selectedPolicyItems);
      _addressController.text = workspace.address;
      _selectedCity = workspace.city;
      _latitude = workspace.latitude;
      _longitude = workspace.longitude;
      _locationSet = workspace.latitude != 0 || workspace.longitude != 0;
      _phoneController.text = workspace.phone ?? '';
      _emailController.text = workspace.email ?? '';
      _selectedAmenities = List.from(workspace.amenities);
      _isAvailable = workspace.isAvailable;
      _existingLegalDocumentUrl = workspace.legalDocumentUrl;

      final openingParts = workspace.openingTime.split(':');
      final closingParts = workspace.closingTime.split(':');
      if (openingParts.length == 2) {
        _openingTime = TimeOfDay(
          hour: int.parse(openingParts[0]),
          minute: int.parse(openingParts[1]),
        );
      }
      if (closingParts.length == 2) {
        _closingTime = TimeOfDay(
          hour: int.parse(closingParts[0]),
          minute: int.parse(closingParts[1]),
        );
      }

      for (var category in workspace.categoryOptions) {
        final form = _categoryForms[category.type];
        if (form != null) {
          form.enabled = true;
          form.pricePerDayController.text = category.pricePerDay.toString();
          form.pricePerHourController.text = category.pricePerHour.toString();

          final units = category.effectiveUnitImages;
          final unitCount = category.type == AppConstants.workspaceTypePrivate
              ? category.capacity
              : (category.noOfUnits ?? (units.isNotEmpty ? units.length : 1));

          form.noOfOfficesController.text = unitCount.toString();
          if (category.type != AppConstants.workspaceTypePrivate) {
            form.desksPerRoomController.text = category.capacity.toString();
          }

          _syncCategoryUnitBuckets(form);
          for (var i = 0; i < units.length && i < form.unitImageBuckets.length; i++) {
            form.unitImageBuckets[i].existingImageUrls.addAll(units[i]);
          }
        }
      }
      _existingGeneralImageUrls
        ..clear()
        ..addAll(workspace.imageUrls);
    }
  }

  @override
  void dispose() {
    _priceSuggestionDebounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _customDescriptionController.dispose();
    _customPolicyController.dispose();
    _customAmenityController.dispose();
    for (final form in _categoryForms.values) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLegalDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path != null) {
      setState(() => _legalDocument = XFile(file.path!));
    } else if (file.bytes != null) {
      setState(() => _legalDocument = XFile.fromData(
            file.bytes!,
            name: file.name,
            mimeType: file.extension != null ? 'application/${file.extension}' : null,
          ));
    }
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 60);
    if (images.isEmpty) return;

    setState(() {
      _selectedImages.addAll(
        images.take(10 - _existingGeneralImageUrls.length - _selectedImages.length),
      );
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickCategoryImages(_CategoryFormData form, int unitIndex) async {
    if (unitIndex < 0 || unitIndex >= form.unitImageBuckets.length) return;
    final bucket = form.unitImageBuckets[unitIndex];
    final total = bucket.existingImageUrls.length + bucket.selectedImages.length;
    if (total >= 5) return;
    final images = await _imagePicker.pickMultiImage(imageQuality: 60);
    if (images.isEmpty) return;
    setState(() {
      bucket.selectedImages.addAll(images.take(5 - total));
    });
  }

  void _removeCategoryImage(
    _CategoryFormData form,
    int unitIndex,
    int imageIndex, {
    required bool existing,
  }) {
    setState(() {
      final bucket = form.unitImageBuckets[unitIndex];
      if (existing) {
        bucket.existingImageUrls.removeAt(imageIndex);
      } else {
        bucket.selectedImages.removeAt(imageIndex);
      }
    });
  }

  int _unitCountForForm(_CategoryFormData form) {
    final n = int.tryParse(form.noOfOfficesController.text.trim()) ?? 1;
    return n.clamp(1, 50);
  }

  void _syncCategoryUnitBuckets(_CategoryFormData form) {
    final count = _unitCountForForm(form);
    while (form.unitImageBuckets.length < count) {
      form.unitImageBuckets.add(_UnitImageData());
    }
    while (form.unitImageBuckets.length > count) {
      form.unitImageBuckets.removeLast();
    }
  }

  String _unitPhotoLabel(String type, String categoryLabel, int unitIndex) {
    final n = unitIndex + 1;
    switch (type) {
      case AppConstants.workspaceTypePrivate:
        return 'Private Office $n';
      case AppConstants.workspaceTypeMeetingRoom:
        return 'Meeting Room $n';
      case AppConstants.workspaceTypeShared:
        return 'Shared Space $n';
      default:
        return '$categoryLabel $n';
    }
  }

  void _removeExistingGeneralImage(int index) {
    setState(() => _existingGeneralImageUrls.removeAt(index));
  }

  List<String> get _customDescriptionItems => _selectedDescriptionItems
      .where((item) => !AppConstants.workspaceDescriptionHighlights.contains(item))
      .toList();

  List<String> get _customPolicyItems => _selectedPolicyItems
      .where((item) => !AppConstants.commonOfficePolicies.contains(item))
      .toList();

  void _parseListedText(String? text, List<String> target) {
    target.clear();
    if (text == null || text.trim().isEmpty) return;

    final lines = text.split('\n');
    if (lines.length == 1 && !text.trim().startsWith('•')) {
      target.add(text.trim());
      return;
    }

    for (final raw in lines) {
      final cleaned = raw.replaceFirst(RegExp(r'^[\s•\-*]+'), '').trim();
      if (cleaned.isEmpty) continue;
      if (!target.contains(cleaned)) target.add(cleaned);
    }
  }

  String _compileListedText(List<String> items) {
    if (items.isEmpty) return '';
    return items.map((item) => '• $item').join('\n');
  }

  void _addCustomDescription([String? raw]) {
    final value = (raw ?? _customDescriptionController.text).trim();
    if (value.isEmpty) return;
    if (_selectedDescriptionItems.any((e) => e.toLowerCase() == value.toLowerCase())) {
      showErrorSnackBar(context, 'This description point is already added');
      return;
    }
    setState(() {
      _selectedDescriptionItems.add(value);
      _customDescriptionController.clear();
    });
  }

  void _addCustomPolicy([String? raw]) {
    final value = (raw ?? _customPolicyController.text).trim();
    if (value.isEmpty) return;
    if (_selectedPolicyItems.any((e) => e.toLowerCase() == value.toLowerCase())) {
      showErrorSnackBar(context, 'This policy is already added');
      return;
    }
    setState(() {
      _selectedPolicyItems.add(value);
      _customPolicyController.clear();
    });
  }

  void _removeCustomDescription(String item) {
    setState(() => _selectedDescriptionItems.remove(item));
  }

  void _removeCustomPolicy(String item) {
    setState(() => _selectedPolicyItems.remove(item));
  }

  List<String> get _customAmenities => _selectedAmenities
      .where((a) => !AppConstants.commonAmenities.contains(a))
      .toList();

  void _addCustomAmenity([String? raw]) {
    final value = (raw ?? _customAmenityController.text).trim();
    if (value.isEmpty) return;

    final exists = _selectedAmenities.any(
      (a) => a.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      showErrorSnackBar(context, 'This amenity is already added');
      return;
    }

    setState(() {
      _selectedAmenities.add(value);
      _customAmenityController.clear();
    });
    _schedulePriceSuggestions();
  }

  void _removeCustomAmenity(String amenity) {
    setState(() => _selectedAmenities.remove(amenity));
    _schedulePriceSuggestions();
  }

  void _schedulePriceSuggestions() {
    _priceSuggestionDebounce?.cancel();
    _priceSuggestionDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _fetchAllEnabledSuggestions();
    });
  }

  int _capacityForCategory(String type, _CategoryFormData form) {
    if (type == AppConstants.workspaceTypePrivate) {
      return int.tryParse(form.noOfOfficesController.text.trim()) ?? 1;
    }
    return int.tryParse(form.desksPerRoomController.text.trim()) ??
        int.tryParse(form.noOfOfficesController.text.trim()) ??
        1;
  }

  Future<void> _fetchPriceSuggestion(String type) async {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      if (mounted) {
        showErrorSnackBar(context, 'Pick location on map first for a price guide');
      }
      return;
    }

    final form = _categoryForms[type];
    if (form == null || !form.enabled) return;

    setState(() => _priceSuggestionLoading[type] = true);

    try {
      final suggestion = await _pricePredictionService.predict(
        city: serviceCityForPricing(_selectedCity, _latitude, _longitude),
        workspaceType: type,
        capacity: _capacityForCategory(type, form),
        amenities: _selectedAmenities,
        excludeWorkspaceId: widget.workspaceToEdit?.id,
      );
      if (!mounted) return;
      setState(() {
        _priceSuggestions[type] = suggestion;
        _priceSuggestionLoading[type] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _priceSuggestionLoading[type] = false);
      showErrorSnackBar(context, 'Could not load price guide');
    }
  }

  Future<void> _fetchAllEnabledSuggestions() async {
    if (_selectedCity == null || _selectedCity!.isEmpty) return;

    for (final entry in _categoryForms.entries) {
      if (entry.value.enabled) {
        await _fetchPriceSuggestion(entry.key);
      }
    }
  }

  void _applyPriceSuggestion(String type) {
    final suggestion = _priceSuggestions[type];
    final form = _categoryForms[type];
    if (suggestion == null || form == null) return;

    setState(() {
      form.pricePerDayController.text =
          suggestion.pricePerDaySuggested.toStringAsFixed(0);
      form.pricePerHourController.text =
          suggestion.pricePerHourSuggested.toStringAsFixed(0);
    });
    showInfoSnackBar(context, 'Prices updated from guide');
  }

  Widget _buildPriceSuggestionCard(String type, _CategoryFormData formData) {
    final suggestion = _priceSuggestions[type];
    final isLoading = _priceSuggestionLoading[type] ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CAppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(
          color: CAppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.price_change_outlined,
                size: 18,
                color: CAppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Price Guide',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: CAppTheme.textPrimary,
                  ),
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CAppTheme.primaryColor,
                  ),
                )
              else
                IconButton(
                  onPressed: () => _fetchPriceSuggestion(type),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: CAppTheme.primaryColor,
                  ),
                  tooltip: 'Refresh price guide',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (isLoading && suggestion == null) ...[
            const SizedBox(height: 8),
            Text(
              'Checking prices in your area...',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: CAppTheme.textSecondary,
              ),
            ),
          ],
          if (suggestion != null && !isLoading) ...[
            const SizedBox(height: 10),
            Text(
              'Rs. ${suggestion.pricePerDayMin.toStringAsFixed(0)} – '
              '${suggestion.pricePerDayMax.toStringAsFixed(0)}/day',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: CAppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rs. ${suggestion.pricePerHourMin.toStringAsFixed(0)} – '
              '${suggestion.pricePerHourMax.toStringAsFixed(0)}/hour',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: CAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Suggested: Rs. ${suggestion.pricePerDaySuggested.toStringAsFixed(0)}/day',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _buildConfidenceChip(suggestion),
            const SizedBox(height: 8),
            Text(
              suggestion.reason,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: CAppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _applyPriceSuggestion(type),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CAppTheme.primaryColor,
                  side: BorderSide(color: CAppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Use this price',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (suggestion == null && !isLoading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _fetchPriceSuggestion(type),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CAppTheme.primaryColor,
                  side: BorderSide(color: CAppTheme.primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                ),
                icon: const Icon(Icons.price_change_outlined, size: 18),
                label: Text(
                  'Get price guide',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceChip(PriceSuggestion suggestion) {
    final (label, color) = switch (suggestion.confidence) {
      PriceConfidence.high => ('Many similar listings', CAppTheme.successColor),
      PriceConfidence.medium => ('Some similar listings', Colors.orange),
      PriceConfidence.low => ('City rate estimate', Colors.blueGrey),
    };

    final sampleText = suggestion.sampleSize > 0
        ? ' · ${suggestion.sampleSize} workspace${suggestion.sampleSize == 1 ? '' : 's'}'
        : ' · few local listings';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label$sampleText',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  LatLng _initialMapCenter() => defaultCenterForCity(_selectedCity);

  Future<void> _pickLocationOnMap() async {
    final center = _initialMapCenter();
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerMap(
          initialLatitude: _locationSet ? _latitude : center.latitude,
          initialLongitude: _locationSet ? _longitude : center.longitude,
          city: _selectedCity,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _locationSet = true;
      _addressController.text = result.address;
      _selectedCity = result.city;
      _schedulePriceSuggestions();
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Future<void> _selectTime({required bool isOpening}) async {
    final initialTime = isOpening ? _openingTime : _closingTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  List<WorkspaceTimeSlotTemplate> _generateTimeSlots() {
    final slots = <WorkspaceTimeSlotTemplate>[];
    int startHour = _openingTime.hour;
    final endHour = _closingTime.hour;

    if (endHour <= startHour) return slots;

    for (int hour = startHour; hour < endHour; hour++) {
      final label =
          '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00';
      slots.add(
        WorkspaceTimeSlotTemplate(
          id: const Uuid().v4(),
          label: label,
          startHour: hour,
          endHour: hour + 1,
        ),
      );
    }
    return slots;
  }

  Widget _buildImagePicker() {
    final children = <Widget>[
      ...List.generate(_existingGeneralImageUrls.length, (index) {
        final url = _existingGeneralImageUrls[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Image.network(url, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeExistingGeneralImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: CAppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      }),
      ...List.generate(_selectedImages.length, (index) {
        final file = _selectedImages[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              child: SizedBox(
                width: 100,
                height: 100,
                child: FutureBuilder(
                  future: file.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      return Image.memory(
                        snapshot.data as Uint8List,
                        fit: BoxFit.cover,
                      );
                    }
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CAppTheme.primaryColor,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: CAppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      }),
      if (_existingGeneralImageUrls.length + _selectedImages.length < 10)
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              border: Border.all(
                color: CAppTheme.primaryColor,
                width: 1.5,
                style: BorderStyle.solid,
              ),
              color: CAppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  color: CAppTheme.primaryColor,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: CAppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }

  Widget _buildCategoryImagePicker(String type, _CategoryFormData formData) {
    _syncCategoryUnitBuckets(formData);
    final unitCount = formData.unitImageBuckets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(unitCount, (unitIndex) {
        final bucket = formData.unitImageBuckets[unitIndex];
        final total = bucket.existingImageUrls.length + bucket.selectedImages.length;
        final unitLabel = _unitPhotoLabel(type, formData.label, unitIndex);

        final children = <Widget>[
          ...List.generate(bucket.existingImageUrls.length, (index) {
            final url = bucket.existingImageUrls[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeCategoryImage(
                      formData,
                      unitIndex,
                      index,
                      existing: true,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: CAppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            );
          }),
          ...List.generate(bucket.selectedImages.length, (index) {
            final file = bucket.selectedImages[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: FutureBuilder(
                      future: file.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Image.memory(
                            snapshot.data as Uint8List,
                            fit: BoxFit.cover,
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeCategoryImage(
                      formData,
                      unitIndex,
                      index,
                      existing: false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: CAppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            );
          }),
          if (total < 5)
            GestureDetector(
              onTap: () => _pickCategoryImages(formData, unitIndex),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  border: Border.all(color: CAppTheme.borderColor),
                  color: CAppTheme.backgroundColor,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 22, color: CAppTheme.primaryColor),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: CAppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ];

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: unitIndex < unitCount - 1 ? 14 : 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CAppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            border: Border.all(color: CAppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unitLabel,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'At least 1 photo required',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: total == 0 ? CAppTheme.errorColor : CAppTheme.textSecondary,
                  fontWeight: total == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: children),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCategoryCard(String type, _CategoryFormData formData) {
    final isShared = type == AppConstants.workspaceTypeShared;
    final isMeetingRoom = type == AppConstants.workspaceTypeMeetingRoom;
    final limits = WorkspaceCategoryLimits.forType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: formData.enabled
            ? Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.3))
            : Border.all(color: CAppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                formData.label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                'Enable bookings for this workspace type',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: CAppTheme.textSecondary,
                ),
              ),
              value: formData.enabled,
              activeTrackColor: CAppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  formData.enabled = value;
                  if (!value) {
                    _priceSuggestions.remove(type);
                    _priceSuggestionLoading.remove(type);
                  }
                });
                if (value) _schedulePriceSuggestions();
              },
            ),
            if (formData.enabled) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: formData.noOfOfficesController,
                keyboardType: TextInputType.number,
                inputFormatters: FormValidators.digitsOnly(),
                decoration: InputDecoration(
                  labelText: 'No of Offices *',
                  helperText:
                      'Min ${limits.officesMin}, max ${limits.officesMax}',
                  prefixIcon: Icon(Icons.business_outlined, color: CAppTheme.textSecondary),
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
                ),
                validator: (value) => FormValidators.positiveInt(
                  value,
                  required: formData.enabled,
                  min: limits.officesMin,
                  max: limits.officesMax,
                  label: 'Number of offices',
                ),
                onChanged: (_) {
                  _syncCategoryUnitBuckets(formData);
                  _schedulePriceSuggestions();
                  setState(() {});
                },
              ),
              if (isShared || isMeetingRoom) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: formData.desksPerRoomController,
                  keyboardType: TextInputType.number,
                  inputFormatters: FormValidators.digitsOnly(),
                  decoration: InputDecoration(
                    labelText: isShared
                        ? 'Room Capacity (Desks) *'
                        : 'Desks per Room *',
                    helperText:
                        'Min ${limits.desksMin}, max ${limits.desksMax}',
                    prefixIcon: Icon(Icons.chair_outlined, color: CAppTheme.textSecondary),
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
                  ),
                  validator: (value) => FormValidators.positiveInt(
                    value,
                    required: formData.enabled,
                    min: limits.desksMin,
                    max: limits.desksMax,
                    label: isShared ? 'Room capacity' : 'Desks per room',
                  ),
                  onChanged: (_) => _schedulePriceSuggestions(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: formData.pricePerDayController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: FormValidators.decimalPrice(),
                      decoration: InputDecoration(
                        labelText: 'Price/Day *',
                        helperText:
                            'Rs. ${limits.pricePerDayMin.toInt()}-${limits.pricePerDayMax.toInt()}',
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: CAppTheme.textSecondary),
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
                      ),
                      validator: (value) => FormValidators.price(
                        value,
                        required: formData.enabled,
                        min: limits.pricePerDayMin,
                        max: limits.pricePerDayMax,
                        label: 'Price per day',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: formData.pricePerHourController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: FormValidators.decimalPrice(),
                      decoration: InputDecoration(
                        labelText: 'Price/Hour *',
                        helperText:
                            'Rs. ${limits.pricePerHourMin.toInt()}-${limits.pricePerHourMax.toInt()}',
                        prefixIcon: Icon(Icons.access_time_outlined, color: CAppTheme.textSecondary),
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
                      ),
                      validator: (value) => FormValidators.price(
                        value,
                        required: formData.enabled,
                        min: limits.pricePerHourMin,
                        max: limits.pricePerHourMax,
                        label: 'Price per hour',
                      ),
                    ),
                  ),
                ],
              ),
              _buildPriceSuggestionCard(type, formData),
              const SizedBox(height: 16),
              Text(
                'Photos for ${formData.label} *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each office/room needs at least 1 photo (up to 5 per unit)',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: CAppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildCategoryImagePicker(type, formData),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_locationSet) {
      showErrorSnackBar(context, 'Please select location on map');
      return;
    }

    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      showErrorSnackBar(context, 'Please pick location on map');
      return;
    }

    if (_selectedAmenities.isEmpty) {
      showErrorSnackBar(context, 'Please select at least one amenity');
      return;
    }

    if (_selectedDescriptionItems.isEmpty) {
      showErrorSnackBar(
        context,
        'Select or add at least one description point',
      );
      return;
    }

    final descriptionText = _compileListedText(_selectedDescriptionItems);
    if (descriptionText.length < ValidationLimits.descriptionMin) {
      showErrorSnackBar(
        context,
        'Add more description points (at least ${ValidationLimits.descriptionMin} characters total)',
      );
      return;
    }

    final enabledCategories = _categoryForms.entries
        .where((entry) => entry.value.enabled)
        .toList();

    if (enabledCategories.isEmpty) {
      showErrorSnackBar(
        context,
        'Please enable at least one workspace category',
      );
      return;
    }

    for (var entry in enabledCategories) {
      final form = entry.value;
      if (form.noOfOfficesController.text.trim().isEmpty) {
        showErrorSnackBar(
          context,
          'Please enter number of offices for ${form.label}',
        );
        return;
      }

      final noOfOffices = int.tryParse(form.noOfOfficesController.text.trim());
      if (noOfOffices == null || noOfOffices <= 0) {
        showErrorSnackBar(
          context,
          'Please enter a valid number of offices for ${form.label}',
        );
        return;
      }

      if (entry.key != AppConstants.workspaceTypePrivate) {
        if (form.desksPerRoomController.text.trim().isEmpty) {
          showErrorSnackBar(
            context,
            'Please enter desks per room for ${form.label}',
          );
          return;
        }

        final desksPerRoom = int.tryParse(
          form.desksPerRoomController.text.trim(),
        );
        if (desksPerRoom == null || desksPerRoom <= 0) {
          showErrorSnackBar(
            context,
            'Please enter a valid number of desks per room for ${form.label}',
          );
          return;
        }
      }

      if (form.pricePerDayController.text.trim().isEmpty) {
        showErrorSnackBar(
          context,
          'Please enter price per day for ${form.label}',
        );
        return;
      }

      final pricePerDay = double.tryParse(
        form.pricePerDayController.text.trim(),
      );
      if (pricePerDay == null || pricePerDay <= 0) {
        showErrorSnackBar(
          context,
          'Please enter a valid price per day for ${form.label}',
        );
        return;
      }

      if (form.pricePerHourController.text.trim().isEmpty) {
        showErrorSnackBar(
          context,
          'Please enter price per hour for ${form.label}',
        );
        return;
      }

      final pricePerHour = double.tryParse(
        form.pricePerHourController.text.trim(),
      );
      if (pricePerHour == null || pricePerHour <= 0) {
        showErrorSnackBar(
          context,
          'Please enter a valid price per hour for ${form.label}',
        );
        return;
      }

      _syncCategoryUnitBuckets(form);
      for (var u = 0; u < form.unitImageBuckets.length; u++) {
        final bucket = form.unitImageBuckets[u];
        if (bucket.existingImageUrls.isEmpty && bucket.selectedImages.isEmpty) {
          showErrorSnackBar(
            context,
            'Please add at least one photo for ${_unitPhotoLabel(entry.key, form.label, u)}',
          );
          return;
        }
      }
    }

    if (_selectedImages.isEmpty &&
        _existingGeneralImageUrls.isEmpty &&
        widget.workspaceToEdit == null) {
      showErrorSnackBar(context, 'Please add at least one workspace photo');
      return;
    }

    final isNew = widget.workspaceToEdit == null;
    if (isNew && _legalDocument == null) {
      showErrorSnackBar(
        context,
        'Please upload a legal/ownership document for this workspace',
      );
      return;
    }

    final openingMinutes = _openingTime.hour * 60 + _openingTime.minute;
    final closingMinutes = _closingTime.hour * 60 + _closingTime.minute;
    if (closingMinutes <= openingMinutes) {
      showErrorSnackBar(context, 'Closing time must be after opening time');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authController = Provider.of<AuthController>(context, listen: false);
    final ownerId = authController.currentUser?.id;

    if (ownerId == null) {
      showErrorSnackBar(context, 'User not found');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final workspaceId = widget.workspaceToEdit?.id ?? const Uuid().v4();
    final storageService = StorageService();
    List<String> uploadedImages = [];
    String? legalDocumentUrl = _existingLegalDocumentUrl;

    if (_legalDocument != null) {
      try {
        legalDocumentUrl = await storageService.uploadWorkspaceLegalDocument(
          workspaceId: workspaceId,
          file: _legalDocument!,
        );
      } catch (e) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'Legal document upload failed: $e');
        return;
      }
    }

    if (_selectedImages.isNotEmpty) {
      try {
        if (mounted) {
          showInfoSnackBar(
            context,
            'Uploading images...',
            duration: const Duration(seconds: 2),
          );
        }

        uploadedImages = await storageService
            .uploadWorkspaceImages(
              workspaceId: workspaceId,
              files: _selectedImages,
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                return <String>[];
              },
            );
      } catch (e) {
        uploadedImages = [];

        if (mounted) {
          showWarningSnackBar(
            context,
            'Image upload failed, but workspace will be created. You can add images later.',
          );
        }
      }
    } else if (widget.workspaceToEdit != null) {
      uploadedImages = List<String>.from(_existingGeneralImageUrls);
    }

    final categoryOptions = <WorkspaceCategoryOption>[];
    for (final entry in enabledCategories) {
      final form = entry.value;
      final noOfOffices = int.parse(form.noOfOfficesController.text.trim());

      final capacity = entry.key == AppConstants.workspaceTypePrivate
          ? noOfOffices
          : int.parse(form.desksPerRoomController.text.trim());

      final pricePerDay = double.parse(form.pricePerDayController.text.trim());
      final pricePerHour = double.parse(
        form.pricePerHourController.text.trim(),
      );

      _syncCategoryUnitBuckets(form);
      final unitImageUrls = <List<String>>[];
      for (var u = 0; u < form.unitImageBuckets.length; u++) {
        final bucket = form.unitImageBuckets[u];
        final urls = List<String>.from(bucket.existingImageUrls);
        if (bucket.selectedImages.isNotEmpty) {
          try {
            final uploaded = await storageService.uploadWorkspaceImages(
              workspaceId: workspaceId,
              files: bucket.selectedImages,
            );
            urls.addAll(uploaded);
          } catch (_) {
            if (mounted) {
              showWarningSnackBar(
                context,
                'Some photos for unit ${u + 1} failed to upload.',
              );
            }
          }
        }
        unitImageUrls.add(urls);
      }

      final flatImages = unitImageUrls.expand((u) => u).toList();

      categoryOptions.add(
        WorkspaceCategoryOption(
          type: entry.key,
          capacity: capacity,
          pricePerHour: pricePerHour,
          pricePerDay: pricePerDay,
          imageUrls: flatImages,
          noOfUnits: entry.key == AppConstants.workspaceTypePrivate
              ? null
              : noOfOffices,
          unitImageUrls: unitImageUrls,
        ),
      );
    }

    final timeSlots = _generateTimeSlots();

    final totalCapacity = categoryOptions.fold<int>(
      0,
      (sum, option) => sum + option.capacity,
    );

    if (categoryOptions.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      showErrorSnackBar(
        context,
        'No category options found. Please enable at least one category.',
      );
      return;
    }

    if (!_locationSet) {
      setState(() => _isLoading = false);
      showErrorSnackBar(context, 'Please pick workspace location on the map.');
      return;
    }

    final workspace = WorkspaceModel(
      id: workspaceId,
      ownerId: ownerId,
      name: _nameController.text.trim(),
      description: descriptionText,
      address: _addressController.text.trim(),
      city: _selectedCity!,
      state: null,
      country: 'Pakistan',
      latitude: _latitude,
      longitude: _longitude,
      pricePerDay: categoryOptions.isNotEmpty
          ? categoryOptions.first.pricePerDay
          : 0,
      pricePerHour: 0,
      capacity: totalCapacity > 0 ? totalCapacity : 1,
      amenities: _selectedAmenities,
      imageUrls: uploadedImages,
      workspaceType: categoryOptions.isNotEmpty
          ? categoryOptions.first.type
          : AppConstants.workspaceTypeShared,
      categoryOptions: categoryOptions,
      timeSlots: widget.workspaceToEdit != null && timeSlots.isEmpty
          ? widget.workspaceToEdit!.timeSlots
          : timeSlots,
      openingTime: _formatTimeOfDay(_openingTime),
      closingTime: _formatTimeOfDay(_closingTime),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      isAvailable: isNew ? false : _isAvailable,
      workspaceApproved: isNew ? null : widget.workspaceToEdit?.workspaceApproved,
      legalDocumentUrl: legalDocumentUrl,
      createdAt: widget.workspaceToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      operatingHours: [
        '${_formatTimeOfDay(_openingTime)} - ${_formatTimeOfDay(_closingTime)}',
      ],
      officePolicies: _selectedPolicyItems.isEmpty
          ? null
          : _compileListedText(_selectedPolicyItems),
    );

    try {
      final controller = Provider.of<WorkspaceController>(
        context,
        listen: false,
      );

      final success = widget.workspaceToEdit != null
          ? await controller
                .updateWorkspace(workspace)
                .timeout(
                  const Duration(seconds: 30),
                  onTimeout: () {
                    throw Exception(
                      'Workspace update timed out. Please check your internet connection.',
                    );
                  },
                )
          : await controller
                .createWorkspace(workspace)
                .timeout(
                  const Duration(seconds: 30),
                  onTimeout: () {
                    throw Exception(
                      'Workspace creation timed out. Please check your internet connection.',
                    );
                  },
                );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (!mounted) return;
        showSuccessSnackBar(
          context,
          widget.workspaceToEdit != null
              ? 'Workspace updated successfully!'
              : 'Workspace submitted! Admin will review your legal document before listing.',
          duration: const Duration(seconds: 3),
        );
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        showErrorSnackBar(
          context,
          controller.errorMessage ?? 'Failed to add workspace',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final errorMessage = e.toString().contains('column')
          ? 'Database column error. Please check Supabase table structure.'
          : e.toString().contains('permission') ||
                e.toString().contains('policy')
          ? 'Permission denied. Please check Supabase RLS policies.'
          : e.toString().contains('null')
          ? 'Missing required fields. Please fill all required fields.'
          : 'Error adding workspace: $e';

      showErrorSnackBar(
        context,
        errorMessage,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: CAppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.workspaceToEdit != null ? 'Edit Workspace' : 'Add Workspace',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: CAppTheme.textPrimary,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),
              _buildThemedTextField(
                controller: _nameController,
                label: 'Workspace Name *',
                icon: Icons.workspaces_outlined,
                validator: FormValidators.workspaceName,
              ),
              const SizedBox(height: 16),
              _buildListedChipSection(
                title: 'Description *',
                subtitle: 'Select highlights that describe your space, or add your own',
                options: AppConstants.workspaceDescriptionHighlights,
                selected: _selectedDescriptionItems,
                customItems: _customDescriptionItems,
                customController: _customDescriptionController,
                onToggle: (item, isSelected) {
                  setState(() {
                    if (isSelected) {
                      _selectedDescriptionItems.add(item);
                    } else {
                      _selectedDescriptionItems.remove(item);
                    }
                  });
                },
                onAddCustom: _addCustomDescription,
                onRemoveCustom: _removeCustomDescription,
                customHint: 'Add custom description point',
              ),
              const SizedBox(height: 16),
              _buildListedChipSection(
                title: 'Office Policies',
                subtitle: 'Select rules guests should follow (optional)',
                options: AppConstants.commonOfficePolicies,
                selected: _selectedPolicyItems,
                customItems: _customPolicyItems,
                customController: _customPolicyController,
                onToggle: (item, isSelected) {
                  setState(() {
                    if (isSelected) {
                      _selectedPolicyItems.add(item);
                    } else {
                      _selectedPolicyItems.remove(item);
                    }
                  });
                },
                onAddCustom: _addCustomPolicy,
                onRemoveCustom: _removeCustomPolicy,
                customHint: 'Add custom policy',
              ),
              const SizedBox(height: 16),
              _buildMapLocationPicker(),
              const SizedBox(height: 16),
              _buildThemedTextField(
                controller: _addressController,
                label: 'Address * (auto-filled from map)',
                icon: Icons.location_on_outlined,
                validator: FormValidators.address,
              ),
              const SizedBox(height: 20),

              // Photos Section
              _buildSectionHeader('General Workspace Photos *'),
              const SizedBox(height: 6),
              Text(
                'Building exterior, reception, or overall space (max 10)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: CAppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildImagePicker(),
              const SizedBox(height: 20),

              _buildSectionHeader('Legal / Ownership Document *'),
              const SizedBox(height: 8),
              Text(
                widget.workspaceToEdit == null
                    ? 'Upload rent agreement, property deed, or business registration. Admin must approve before your workspace is listed.'
                    : 'Upload a new document only if you need to replace the existing one.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: CAppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickLegalDocument,
                icon: const Icon(Icons.description_outlined),
                label: Text(
                  _legalDocument != null
                      ? _legalDocument!.name
                      : (_existingLegalDocumentUrl != null
                          ? 'Document on file — replace'
                          : 'Upload legal document (PDF/JPG/PNG)'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Location Section
              _buildSectionHeader('Location & Hours'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  border: Border.all(color: CAppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_city_outlined, color: CAppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'City (from map)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedCity ?? 'Pick location on map above',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _selectedCity != null
                                  ? CAppTheme.textPrimary
                                  : CAppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedCity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CAppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                        ),
                        child: Text(
                          'Auto',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CAppTheme.successColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(isOpening: true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: CAppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                        foregroundColor: CAppTheme.textPrimary,
                      ),
                      icon: Icon(Icons.login, color: CAppTheme.primaryColor, size: 20),
                      label: Text(
                        'Opens: ${_formatTimeOfDay(_openingTime)}',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(isOpening: false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: CAppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                        foregroundColor: CAppTheme.textPrimary,
                      ),
                      icon: Icon(Icons.logout, color: CAppTheme.primaryColor, size: 20),
                      label: Text(
                        'Closes: ${_formatTimeOfDay(_closingTime)}',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Categories Section
              Row(
                children: [
                  Expanded(child: _buildSectionHeader('Workspace Categories')),
                  TextButton.icon(
                    onPressed: _selectedCity == null
                        ? null
                        : _fetchAllEnabledSuggestions,
                    icon: Icon(
                      Icons.price_change_outlined,
                      size: 18,
                      color: _selectedCity == null
                          ? CAppTheme.textTertiary
                          : CAppTheme.primaryColor,
                    ),
                    label: Text(
                      'All price guides',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedCity == null
                            ? CAppTheme.textTertiary
                            : CAppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._categoryForms.entries.map(
                (entry) => _buildCategoryCard(entry.key, entry.value),
              ),
              const SizedBox(height: 8),

              // Amenities Section
              _buildSectionHeader('Amenities *'),
              const SizedBox(height: 8),
              Text(
                'Pick from common options or add your own',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: CAppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.commonAmenities.map((amenity) {
                  final isSelected = _selectedAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(
                      amenity,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : CAppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: CAppTheme.primaryColor,
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      side: BorderSide(
                        color: isSelected ? CAppTheme.primaryColor : CAppTheme.borderColor,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                      _schedulePriceSuggestions();
                    },
                  );
                }).toList(),
              ),
              if (_customAmenities.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Custom amenities',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customAmenities.map((amenity) {
                    return InputChip(
                      label: Text(
                        amenity,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: CAppTheme.primaryColor,
                        ),
                      ),
                      backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.08),
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: CAppTheme.primaryColor,
                      ),
                      onDeleted: () => _removeCustomAmenity(amenity),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        side: BorderSide(
                          color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _customAmenityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Add other amenity (e.g. Printer, Gym)',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: CAppTheme.textTertiary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          borderSide: const BorderSide(color: CAppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          borderSide: const BorderSide(color: CAppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          borderSide: const BorderSide(
                            color: CAppTheme.primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onFieldSubmitted: _addCustomAmenity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: CAppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    child: InkWell(
                      onTap: () => _addCustomAmenity(),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Availability Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  boxShadow: CAppTheme.softShadow,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Available',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Make this workspace visible to users',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                  value: _isAvailable,
                  activeTrackColor: CAppTheme.successColor,
                  onChanged: (value) {
                    setState(() {
                      _isAvailable = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CAppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.workspaceToEdit != null
                            ? 'Update Workspace'
                            : 'Add Workspace',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Map Location *'),
        const SizedBox(height: 8),
        Text(
          'Search on map or tap to pin — address will fill automatically.',
          style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
        ),
        if (_locationSet && _addressController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_rounded, size: 18, color: CAppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _addressController.text,
                    style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_locationSet) ...[
          WorkspaceMapView(latitude: _latitude, longitude: _longitude),
          const SizedBox(height: 8),
          Text(
            'Lat: ${_latitude.toStringAsFixed(5)}, Lng: ${_longitude.toStringAsFixed(5)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
        ] else
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: CAppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              border: Border.all(color: CAppTheme.borderColor),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 36, color: CAppTheme.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'No location selected',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickLocationOnMap,
          icon: const Icon(Icons.map_rounded),
          label: Text(
            _locationSet ? 'Change Location on Map' : 'Select Location on Map',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: CAppTheme.primaryColor),
            foregroundColor: CAppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListedChipSection({
    required String title,
    required String subtitle,
    required List<String> options,
    required List<String> selected,
    required List<String> customItems,
    required TextEditingController customController,
    required void Function(String item, bool isSelected) onToggle,
    required void Function([String? raw]) onAddCustom,
    required void Function(String item) onRemoveCustom,
    required String customHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: CAppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((item) {
            final isSelected = selected.contains(item);
            return FilterChip(
              label: Text(
                item,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : CAppTheme.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: CAppTheme.primaryColor,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                side: BorderSide(
                  color: isSelected ? CAppTheme.primaryColor : CAppTheme.borderColor,
                ),
              ),
              onSelected: (value) => onToggle(item, value),
            );
          }).toList(),
        ),
        if (customItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Custom',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customItems.map((item) {
              return InputChip(
                label: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: CAppTheme.primaryColor,
                  ),
                ),
                backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.08),
                deleteIcon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: CAppTheme.primaryColor,
                ),
                onDeleted: () => onRemoveCustom(item),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  side: BorderSide(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: customController,
                style: GoogleFonts.poppins(color: CAppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: customHint,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: CAppTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
                    borderSide: const BorderSide(
                      color: CAppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onFieldSubmitted: onAddCustom,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => onAddCustom(),
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: CAppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: CAppTheme.textPrimary,
      ),
    );
  }

  Widget _buildThemedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: CAppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(color: CAppTheme.textSecondary),
        prefixIcon: Icon(icon, color: CAppTheme.textSecondary),
        filled: true,
        fillColor: Colors.white,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          borderSide: BorderSide(color: CAppTheme.errorColor),
        ),
      ),
      validator: validator,
    );
  }
}
