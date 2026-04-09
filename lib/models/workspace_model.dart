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

    if (categoryOptions.isNotEmpty) {
      map['category_options'] = categoryOptions.map((e) {
        if (e is WorkspaceCategoryOption) {
          return e.toCategoryMap();
        } else if (e is Map) {
          return Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        } else {
          return <String, dynamic>{};
        }
      }).toList();
    }

    if (timeSlots.isNotEmpty) {
      map['time_slots'] = timeSlots.map((e) {
        if (e is WorkspaceTimeSlotTemplate) {
          return e.toTimeSlotMap();
        } else if (e is Map) {
          return Map<String, dynamic>.from(e as Map<dynamic, dynamic>);
        } else {
          return <String, dynamic>{};
        }
      }).toList();
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
          getValueFromMap(map, 'is_available', 'isAvailable', true) as bool,
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      workspaceType:
          getStringFromMap(map, 'workspace_type', 'workspaceType') ?? 'shared',
      categoryOptions:
          getListFromMap(map, 'category_options', 'categoryOptions') != null
          ? ((getListFromMap(map, 'category_options', 'categoryOptions') ?? [])
                    as List)
                .map(
                  (e) => e is WorkspaceCategoryOption
                      ? e
                      : WorkspaceCategoryOption.fromCategoryMap(
                          e is Map
                              ? Map<String, dynamic>.from(
                                  e as Map<dynamic, dynamic>,
                                )
                              : <String, dynamic>{},
                        ),
                )
                .toList()
          : const [],
      timeSlots: getListFromMap(map, 'time_slots', 'timeSlots') != null
          ? ((getListFromMap(map, 'time_slots', 'timeSlots') ?? []) as List)
                .map(
                  (e) => e is WorkspaceTimeSlotTemplate
                      ? e
                      : WorkspaceTimeSlotTemplate.fromTimeSlotMap(
                          e is Map
                              ? Map<String, dynamic>.from(
                                  e as Map<dynamic, dynamic>,
                                )
                              : <String, dynamic>{},
                        ),
                )
                .toList()
          : const [],
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
    );
  }
}

class WorkspaceCategoryOption {
  final String type;
  final int capacity;
  final double pricePerHour;
  final double pricePerDay;

  const WorkspaceCategoryOption({
    required this.type,
    required this.capacity,
    required this.pricePerHour,
    required this.pricePerDay,
  });

  /// Converts category option to map for storage
  Map<String, dynamic> toCategoryMap() {
    return {
      'type': type,
      'capacity': capacity,
      'pricePerHour': pricePerHour,
      'pricePerDay': pricePerDay,
    };
  }

  factory WorkspaceCategoryOption.fromCategoryMap(Map<String, dynamic> map) {
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
