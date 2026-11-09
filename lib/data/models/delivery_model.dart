import 'package:latlong2/latlong.dart';

enum DeliveryStatus { pending, assigned, enRoute, delivered }

extension DeliveryStatusX on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.assigned:
        return 'Assigned';
      case DeliveryStatus.enRoute:
        return 'En route';
      case DeliveryStatus.delivered:
        return 'Delivered';
    }
  }

  static DeliveryStatus fromString(String v) => DeliveryStatus.values
      .firstWhere((e) => e.name == v, orElse: () => DeliveryStatus.pending);
}

class SchoolLocation {
  SchoolLocation({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.addedByUserId,
    this.isSynced = false,
  });

  final int? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int addedByUserId;
  final bool isSynced;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'added_by_user_id': addedByUserId,
    'is_synced': isSynced ? 1 : 0,
  };

  factory SchoolLocation.fromMap(Map<String, dynamic> m) => SchoolLocation(
    id: m['id'] as int?,
    name: m['name'] as String,
    address: m['address'] as String? ?? '',
    latitude: (m['latitude'] as num).toDouble(),
    longitude: (m['longitude'] as num).toDouble(),
    addedByUserId: m['added_by_user_id'] as int? ?? 0,
    isSynced: (m['is_synced'] as int? ?? 0) == 1,
  );
}

class DeliveryOrder {
  DeliveryOrder({
    this.id,
    required this.schoolId,
    required this.schoolName,
    required this.schoolLat,
    required this.schoolLng,
    required this.pickupLat,
    required this.pickupLng,
    this.assignedDriverId,
    this.assignedDriverName,
    this.status = DeliveryStatus.pending,
    this.createdAt,
    this.isSynced = false,
  });

  final int? id;
  final int schoolId;
  final String schoolName;
  final double schoolLat;
  final double schoolLng;
  final double pickupLat;
  final double pickupLng;
  final int? assignedDriverId;
  final String? assignedDriverName;
  DeliveryStatus status;
  final DateTime? createdAt;
  final bool isSynced;

  LatLng get schoolLatLng => LatLng(schoolLat, schoolLng);
  LatLng get pickupLatLng => LatLng(pickupLat, pickupLng);
  bool get isOpen => assignedDriverId == null;

  String get orderId => 'PAE-${(id ?? 0).toString().padLeft(3, '0')}';

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'school_id': schoolId,
    'school_name': schoolName,
    'school_lat': schoolLat,
    'school_lng': schoolLng,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'assigned_driver_id': assignedDriverId,
    'assigned_driver_name': assignedDriverName,
    'status': status.name,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
  };

  factory DeliveryOrder.fromMap(Map<String, dynamic> m) => DeliveryOrder(
    id: m['id'] as int?,
    schoolId: m['school_id'] as int? ?? 0,
    schoolName: m['school_name'] as String,
    schoolLat: (m['school_lat'] as num).toDouble(),
    schoolLng: (m['school_lng'] as num).toDouble(),
    pickupLat: (m['pickup_lat'] as num).toDouble(),
    pickupLng: (m['pickup_lng'] as num).toDouble(),
    assignedDriverId: m['assigned_driver_id'] as int?,
    assignedDriverName: m['assigned_driver_name'] as String?,
    status: DeliveryStatusX.fromString(m['status'] as String? ?? 'pending'),
    createdAt: m['created_at'] != null
        ? DateTime.tryParse(m['created_at'] as String)
        : null,
    isSynced: (m['is_synced'] as int? ?? 0) == 1,
  );
}
