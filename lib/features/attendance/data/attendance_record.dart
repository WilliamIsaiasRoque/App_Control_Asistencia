class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.workDate,
    this.checkInAt,
    this.checkOutAt,
  });

  final String id;
  final String workerId;
  final String workDate;
  final String? checkInAt;
  final String? checkOutAt;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        workDate: json['work_date'] as String,
        checkInAt: json['check_in_at'] as String?,
        checkOutAt: json['check_out_at'] as String?,
      );

  int get workedMinutes {
    if (checkInAt == null) return 0;
    final start = DateTime.parse(checkInAt!);
    final end = checkOutAt == null
        ? DateTime.now()
        : DateTime.parse(checkOutAt!);
    return end.difference(start).inMinutes.clamp(0, 1000000);
  }
}

class AttendanceMarkResult {
  const AttendanceMarkResult({
    required this.ok,
    this.error,
    this.reason,
    this.event,
    this.siteName,
    this.record,
    this.distanceM,
    this.accuracyM,
    this.radiusM,
    this.maxAccuracyM,
  });

  final bool ok;
  final String? error;
  final String? reason;
  final String? event;
  final String? siteName;
  final AttendanceRecord? record;
  final double? distanceM;
  final double? accuracyM;
  final double? radiusM;
  final double? maxAccuracyM;

  factory AttendanceMarkResult.fromJson(Map<String, dynamic> json) {
    final rawRecord = json['record'];
    return AttendanceMarkResult(
      ok: json['ok'] as bool? ?? false,
      error: json['error'] as String?,
      reason: json['reason'] as String?,
      event: json['event'] as String?,
      siteName: json['site_name'] as String?,
      record: rawRecord is Map
          ? AttendanceRecord.fromJson(Map<String, dynamic>.from(rawRecord))
          : null,
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      radiusM: (json['radius_m'] as num?)?.toDouble(),
      maxAccuracyM: (json['max_accuracy_m'] as num?)?.toDouble(),
    );
  }

  String get diagnosticMessage {
    switch (reason) {
      case 'outside_radius':
      case 'low_accuracy_and_outside_radius':
        return 'La ubicación detectada está fuera del radio permitido de tus locales autorizados.';
      case 'low_accuracy':
        return 'La ubicación llegó con poca precisión. Activa la ubicación precisa e inténtalo otra vez.';
      default:
        return error ?? 'No se pudo validar tu ubicación.';
    }
  }
}
