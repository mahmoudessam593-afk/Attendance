class Employee {
  final String id;
  final String employeeCode;
  final String fullName;
  final String mobileNumber;
  final String? email;
  final String? department;
  final String? position;
  final bool active;
  final DateTime createdAt;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.mobileNumber,
    this.email,
    this.department,
    this.position,
    required this.active,
    required this.createdAt,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      employeeCode: map['employee_code'],
      fullName: map['full_name'],
      mobileNumber: map['mobile_number'],
      email: map['email'],
      department: map['department'],
      position: map['position'],
      active: map['active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_code': employeeCode,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'email': email,
      'department': department,
      'position': position,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Site {
  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool active;
  final DateTime createdAt;

  Site({
    required this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.active,
    required this.createdAt,
  });

  factory Site.fromMap(Map<String, dynamic> map) {
    return Site(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: map['radius_meters'] ?? 50,
      active: map['active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Device {
  final String id;
  final String employeeId;
  final String deviceId;
  final String platform;
  final String deviceName;
  final bool isActive;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;

  Device({
    required this.id,
    required this.employeeId,
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.isActive,
    required this.registeredAt,
    this.lastSeenAt,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      employeeId: map['employee_id'],
      deviceId: map['device_id'],
      platform: map['platform'] ?? '',
      deviceName: map['device_name'] ?? '',
      isActive: map['is_active'] ?? true,
      registeredAt: map['registered_at'] != null
          ? DateTime.parse(map['registered_at'])
          : DateTime.now(),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.parse(map['last_seen_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'device_id': deviceId,
      'platform': platform,
      'device_name': deviceName,
      'is_active': isActive,
      'registered_at': registeredAt.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String siteId;
  final String attendanceType;
  final DateTime attendanceTime;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double distanceMeters;
  final String? deviceId;
  final bool biometricVerified;
  final String status;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.siteId,
    required this.attendanceType,
    required this.attendanceTime,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.distanceMeters,
    this.deviceId,
    required this.biometricVerified,
    required this.status,
    required this.createdAt,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'],
      employeeId: map['employee_id'],
      siteId: map['site_id'],
      attendanceType: map['attendance_type'],
      attendanceTime: DateTime.parse(map['attendance_time']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0.0,
      deviceId: map['device_id'],
      biometricVerified: map['biometric_verified'] ?? false,
      status: map['status'] ?? 'PENDING',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'site_id': siteId,
      'attendance_type': attendanceType,
      'attendance_time': attendanceTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'distance_meters': distanceMeters,
      'device_id': deviceId,
      'biometric_verified': biometricVerified,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}