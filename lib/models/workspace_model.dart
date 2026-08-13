import 'package:cwc/utils/helpers/model_helpers.dart';

class WorkspaceModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final String city;
  final String? state;
  final String country;
  final double latitude;
  final double longitude;
  final double pricePerDay;
  final double pricePerHour;
  final int capacity;
  final List<String> amenities;
  final List<String> imageUrls;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String workspaceType;
  final List<WorkspaceCategoryOption> categoryOptions;
  final List<WorkspaceTimeSlotTemplate> timeSlots;
  final String openingTime;
  final String closingTime;
  final String? phone;
  final String? email;
  final List<String>? operatingHours;
  final double? rating;
  final int? totalReviews;
  final String? officePolicies;
  final String? legalDocumentUrl;
  final bool? workspaceApproved;

  WorkspaceModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    this.state,
    this.country = 'Pakistan',
    required this.latitude,
    required this.longitude,
    required this.pricePerDay,
    this.pricePerHour = 0,
    required this.capacity,
    required this.amenities,
    required this.imageUrls,
    this.isAvailable = true,
    required this.createdAt,
    this.updatedAt,
    this.workspaceType = 'shared',
    this.categoryOptions = const [],
    this.timeSlots = const [],
    this.openingTime = '09:00',
    this.closingTime = '18:00',
    this.phone,
    this.email,
    this.operatingHours,
    this.rating,
    this.totalReviews,
    this.officePolicies,
    this.legalDocumentUrl,
    this.workspaceApproved,
  });

  Map<String, dynamic> toWorkspaceMap() {
    final map = <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'price_per_day': pricePerDay,
      'price_per_hour': pricePerHour,
      'capacity': capacity,
      'amenities': amenities,
      'image_urls': imageUrls,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'workspace_type': workspaceType,
      'opening_time': openingTime,
      'closing_time': closingTime,
    };

    if (state != null) map['state'] = state;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (phone != null) map['phone'] = phone;
    if (email != null) map['email'] = email;
    if (operatingHours != null) map['operating_hours'] = operatingHours;
    if (rating != null) map['rating'] = rating;
    if (totalReviews != null) map['total_reviews'] = totalReviews;
    if (officePolicies != null && officePolicies!.trim().isNotEmpty) {
      map['office_policies'] = officePolicies;
    }
    if (legalDocumentUrl != null) map['legal_document_url'] = legalDocumentUrl;
    if (workspaceApproved != null) map['workspace_approved'] = workspaceApproved;

    if (categoryOptions.isNotEmpty) {
      map['category_options'] = categoryOptions.map((e) => e.toCategoryMap()).toList();
    }

    if (timeSlots.isNotEmpty) {
      map['time_slots'] = timeSlots.map((e) => e.toTimeSlotMap()).toList();
    }

    return map;
  }

  factory WorkspaceModel.fromWorkspaceMap(Map<String, dynamic> map) {
    return WorkspaceModel(
      id: map['id'] ?? '',
      ownerId: getStringFromMap(map, 'owner_id', 'ownerId') ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'],
      country: map['country'] ?? 'Pakistan',
      latitude: convertToDouble(map['latitude'], 0.0),
      longitude: convertToDouble(map['longitude'], 0.0),
      pricePerDay: convertToDouble(
        map['price_per_day'] ?? map['pricePerDay'],
        0.0,
      ),
      pricePerHour: convertToDouble(
        map['price_per_hour'] ?? map['pricePerHour'],
        0.0,
      ),
      capacity: convertToInt(map['capacity'], 0),
      amenities: map['amenities'] != null
          ? List<String>.from(map['amenities'])
          : [],
      imageUrls: getListFromMap(map, 'image_urls', 'imageUrls') != null
          ? List<String>.from(
              getListFromMap(map, 'image_urls', 'imageUrls') ?? [],
            )
          : [],
      isAvailable:
          getValueFromMap(map, 'is_available', 'isAvailable', true),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      workspaceType:
          getStringFromMap(map, 'workspace_type', 'workspaceType') ?? 'shared',
      categoryOptions:
          getListFromMap(map, 'category_options', 'categoryOptions') is List
              ? (getListFromMap(map, 'category_options', 'categoryOptions') as List)
                    .map<WorkspaceCategoryOption>(
                      (e) => e is WorkspaceCategoryOption
                          ? e
                          : WorkspaceCategoryOption.fromCategoryMap(
                              e is Map
                                  ? Map<String, dynamic>.from(e)
                                  : <String, dynamic>{},
                            ),
                    )
                    .toList()
              : const <WorkspaceCategoryOption>[],
      timeSlots:
          getListFromMap(map, 'time_slots', 'timeSlots') is List
              ? (getListFromMap(map, 'time_slots', 'timeSlots') as List)
                    .map<WorkspaceTimeSlotTemplate>(
                      (e) => e is WorkspaceTimeSlotTemplate
                          ? e
                          : WorkspaceTimeSlotTemplate.fromTimeSlotMap(
                              e is Map
                                  ? Map<String, dynamic>.from(e)
                                  : <String, dynamic>{},
                            ),
                    )
                    .toList()
              : const <WorkspaceTimeSlotTemplate>[],
      openingTime:
          getStringFromMap(map, 'opening_time', 'openingTime') ?? '09:00',
      closingTime:
          getStringFromMap(map, 'closing_time', 'closingTime') ?? '18:00',
      phone: map['phone'],
      email: map['email'],
      operatingHours:
          getListFromMap(map, 'operating_hours', 'operatingHours') != null
          ? List<String>.from(
              getListFromMap(map, 'operating_hours', 'operatingHours') ?? [],
            )
          : null,
      rating: map['rating'] != null ? convertToDouble(map['rating'], 0.0) : null,
      totalReviews: map['total_reviews'] != null ? convertToInt(map['total_reviews'], 0) : null,
      officePolicies: getStringFromMap(map, 'office_policies', 'officePolicies'),
      legalDocumentUrl:
          getStringFromMap(map, 'legal_document_url', 'legalDocumentUrl'),
      workspaceApproved: getNullableValueFromMap<bool>(
        map,
        'workspace_approved',
        'workspaceApproved',
      ),
    );
  }

  WorkspaceModel copyWorkspace({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? address,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    double? pricePerDay,
    double? pricePerHour,
    int? capacity,
    List<String>? amenities,
    List<String>? imageUrls,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? workspaceType,
    List<WorkspaceCategoryOption>? categoryOptions,
    List<WorkspaceTimeSlotTemplate>? timeSlots,
    String? openingTime,
    String? closingTime,
    String? phone,
    String? email,
    List<String>? operatingHours,
    double? rating,
    int? totalReviews,
    String? officePolicies,
    String? legalDocumentUrl,
    bool? workspaceApproved,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      capacity: capacity ?? this.capacity,
      amenities: amenities ?? this.amenities,
      imageUrls: imageUrls ?? this.imageUrls,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      workspaceType: workspaceType ?? this.workspaceType,
      categoryOptions: categoryOptions ?? this.categoryOptions,
      timeSlots: timeSlots ?? this.timeSlots,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      operatingHours: operatingHours ?? this.operatingHours,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      officePolicies: officePolicies ?? this.officePolicies,
      legalDocumentUrl: legalDocumentUrl ?? this.legalDocumentUrl,
      workspaceApproved: workspaceApproved ?? this.workspaceApproved,
    );
  }
}

class WorkspaceCategoryOption {
  final String type;
  final int capacity;
  final double pricePerHour;
  final double pricePerDay;
  /// Legacy flat list — derived from [unitImageUrls] when saving.
  final List<String> imageUrls;
  /// Number of offices/rooms (for meeting & shared). For private, equals [capacity].
  final int? noOfUnits;
  /// One image list per office/room (index 0 = unit 1).
  final List<List<String>> unitImageUrls;

  const WorkspaceCategoryOption({
    required this.type,
    required this.capacity,
    required this.pricePerHour,
    required this.pricePerDay,
    this.imageUrls = const [],
    this.noOfUnits,
    this.unitImageUrls = const [],
  });

  List<List<String>> get effectiveUnitImages {
    if (unitImageUrls.isNotEmpty) return unitImageUrls;
    if (imageUrls.isNotEmpty) return [imageUrls];
    return const [];
  }

  /// Converts category option to map for storage
  Map<String, dynamic> toCategoryMap() {
    final flat = unitImageUrls.isNotEmpty
        ? unitImageUrls.expand((u) => u).toList()
        : imageUrls;
    return {
      'type': type,
      'capacity': capacity,
      'pricePerHour': pricePerHour,
      'pricePerDay': pricePerDay,
      if (noOfUnits != null) 'noOfUnits': noOfUnits,
      if (unitImageUrls.isNotEmpty) 'unitImageUrls': unitImageUrls,
      if (flat.isNotEmpty) 'imageUrls': flat,
    };
  }

  factory WorkspaceCategoryOption.fromCategoryMap(Map<String, dynamic> map) {
    final rawUnit = map['unit_image_urls'] ?? map['unitImageUrls'];
    List<List<String>> unitImages = [];
    if (rawUnit is List) {
      for (final unit in rawUnit) {
        if (unit is List) {
          unitImages.add(unit.map((e) => e.toString()).toList());
        }
      }
    }

    final rawImages = map['image_urls'] ?? map['imageUrls'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : <String>[];

    if (unitImages.isEmpty && images.isNotEmpty) {
      unitImages = [images];
    }

    final noOfUnitsRaw = map['no_of_units'] ?? map['noOfUnits'];

    return WorkspaceCategoryOption(
      type: map['type'] ?? '',
      capacity: convertToInt(map['capacity'] ?? map['Capacity'], 0),
      pricePerHour: convertToDouble(
        map['pricePerHour'] ?? map['price_per_hour'],
        0.0,
      ),
      pricePerDay: convertToDouble(
        map['pricePerDay'] ?? map['price_per_day'],
        0.0,
      ),
      imageUrls: images,
      noOfUnits: noOfUnitsRaw != null ? convertToInt(noOfUnitsRaw, 0) : null,
      unitImageUrls: unitImages,
    );
  }
}

class WorkspaceTimeSlotTemplate {
  final String id;
  final String label;
  final int startHour;
  final int endHour;

  const WorkspaceTimeSlotTemplate({
    required this.id,
    required this.label,
    required this.startHour,
    required this.endHour,
  });

  Map<String, dynamic> toTimeSlotMap() {
    return {
      'id': id,
      'label': label,
      'startHour': startHour,
      'endHour': endHour,
    };
  }

  factory WorkspaceTimeSlotTemplate.fromTimeSlotMap(Map<String, dynamic> map) {
    return WorkspaceTimeSlotTemplate(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      startHour: convertToInt(map['startHour'], 9),
      endHour: convertToInt(map['endHour'], 10),
    );
  }
}
