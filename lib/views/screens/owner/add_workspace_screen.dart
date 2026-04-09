/// Add Workspace Screen
/// Allows owners to add a new workspace
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';

class AddWorkspaceScreen extends StatefulWidget {
  final WorkspaceModel? workspaceToEdit;

  const AddWorkspaceScreen({super.key, this.workspaceToEdit});

  @override
  State<AddWorkspaceScreen> createState() => _AddWorkspaceScreenState();
}

class _CategoryFormData {
  final String label;
  final String type;
  bool enabled = false;
  final TextEditingController noOfOfficesController;
  final TextEditingController desksPerRoomController;
  final TextEditingController pricePerDayController;
  final TextEditingController pricePerHourController;

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
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedCity;
  List<String> _selectedAmenities = [];
  bool _isAvailable = true;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
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

  @override
  void initState() {
    super.initState();
    if (widget.workspaceToEdit != null) {
      final workspace = widget.workspaceToEdit!;
      _nameController.text = workspace.name;
      _descriptionController.text = workspace.description;
      _addressController.text = workspace.address;
      _selectedCity = workspace.city;
      _phoneController.text = workspace.phone ?? '';
      _emailController.text = workspace.email ?? '';
      _selectedAmenities = List.from(workspace.amenities);
      _isAvailable = workspace.isAvailable;

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
          form.noOfOfficesController.text = category.capacity.toString();
          form.pricePerDayController.text = category.pricePerDay.toString();
          form.pricePerHourController.text = category.pricePerHour.toString();
          if (category.type != AppConstants.workspaceTypePrivate) {
            form.desksPerRoomController.text = category.capacity.toString();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    for (final form in _categoryForms.values) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 60);
    if (images == null || images.isEmpty) return;

    setState(() {
      _selectedImages.addAll(images.take(10 - _selectedImages.length));
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
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
      if (_selectedImages.length < 10)
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

  Widget _buildCategoryCard(String type, _CategoryFormData formData) {
    final isShared = type == AppConstants.workspaceTypeShared;
    final isMeetingRoom = type == AppConstants.workspaceTypeMeetingRoom;

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
                });
              },
            ),
            if (formData.enabled) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: formData.noOfOfficesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'No of Offices *',
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
                validator: (value) {
                  if (!formData.enabled) return null;
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Invalid';
                  }
                  return null;
                },
              ),
              if (isShared || isMeetingRoom) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: formData.desksPerRoomController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isShared
                        ? 'Room Capacity (Desks) *'
                        : 'Desks per Room *',
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
                  validator: (value) {
                    if (!formData.enabled) return null;
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: formData.pricePerDayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price/Day *',
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
                      validator: (value) {
                        if (!formData.enabled) return null;
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: formData.pricePerHourController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price/Hour *',
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
                      validator: (value) {
                        if (!formData.enabled) return null;
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
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

    if (_selectedCity == null) {
      showErrorSnackBar(context, 'Please select a city');
      return;
    }

    if (_selectedAmenities.isEmpty) {
      showErrorSnackBar(context, 'Please select at least one amenity');
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
    }

    if (_selectedImages.isEmpty && widget.workspaceToEdit == null) {
      showErrorSnackBar(context, 'Please add at least one workspace photo');
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
      uploadedImages = List<String>.from(widget.workspaceToEdit!.imageUrls);
    }

    final categoryOptions = enabledCategories.map((entry) {
      final form = entry.value;
      final noOfOffices = int.parse(form.noOfOfficesController.text.trim());

      final capacity = entry.key == AppConstants.workspaceTypePrivate
          ? noOfOffices
          : int.parse(form.desksPerRoomController.text.trim());

      final pricePerDay = double.parse(form.pricePerDayController.text.trim());
      final pricePerHour = double.parse(
        form.pricePerHourController.text.trim(),
      );

      return WorkspaceCategoryOption(
        type: entry.key,
        capacity: capacity,
        pricePerHour: pricePerHour,
        pricePerDay: pricePerDay,
      );
    }).toList();

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

    final workspace = WorkspaceModel(
      id: workspaceId,
      ownerId: ownerId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      city: _selectedCity!,
      state: null,
      country: 'Pakistan',
      latitude: 0.0,
      longitude: 0.0,
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
          ? (widget.workspaceToEdit!.timeSlots ?? const [])
          : timeSlots,
      openingTime: _formatTimeOfDay(_openingTime),
      closingTime: _formatTimeOfDay(_closingTime),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      isAvailable: _isAvailable,
      createdAt: widget.workspaceToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      operatingHours: [
        '${_formatTimeOfDay(_openingTime)} - ${_formatTimeOfDay(_closingTime)}',
      ],
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
              : 'Workspace added successfully!',
          duration: const Duration(seconds: 2),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter workspace name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildThemedTextField(
                controller: _descriptionController,
                label: 'Description *',
                icon: Icons.description_outlined,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildThemedTextField(
                controller: _addressController,
                label: 'Address *',
                icon: Icons.location_on_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Photos Section
              _buildSectionHeader('Workspace Photos *'),
              const SizedBox(height: 12),
              _buildImagePicker(),
              const SizedBox(height: 20),

              // Location Section
              _buildSectionHeader('Location & Hours'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  labelText: 'City *',
                  labelStyle: GoogleFonts.poppins(color: CAppTheme.textSecondary),
                  prefixIcon: Icon(Icons.location_city_outlined, color: CAppTheme.textSecondary),
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
                ),
                items: AppConstants.cities.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select city';
                  }
                  return null;
                },
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
              _buildSectionHeader('Workspace Categories'),
              const SizedBox(height: 12),
              ..._categoryForms.entries.map(
                (entry) => _buildCategoryCard(entry.key, entry.value),
              ),
              const SizedBox(height: 8),

              // Amenities Section
              _buildSectionHeader('Amenities *'),
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
                    },
                  );
                }).toList(),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: CAppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
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
