import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/user_profile.dart';
import 'attendance_record.dart';

class TeamMemberAttendance {
  const TeamMemberAttendance({required this.profile, this.record});
  final UserProfile profile;
  final AttendanceRecord? record;
}

class TeamMemberHistory {
  const TeamMemberHistory({required this.profile, required this.records});
  final UserProfile profile;
  final List<AttendanceRecord> records;
}

class AttendanceAdjustment {
  const AttendanceAdjustment({
    required this.workerName,
    required this.workDate,
    required this.reason,
    this.oldCheckInAt,
    this.oldCheckOutAt,
    this.newCheckInAt,
    this.newCheckOutAt,
  });
  final String workerName;
  final String workDate;
  final String reason;
  final String? oldCheckInAt;
  final String? oldCheckOutAt;
  final String? newCheckInAt;
  final String? newCheckOutAt;
}

class AttendanceLocationSite {
  const AttendanceLocationSite({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.maxAccuracyM,
    required this.isActive,
    required this.isVisible,
  });
  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int maxAccuracyM;
  final bool isActive;
  final bool isVisible;

  factory AttendanceLocationSite.fromJson(Map<String, dynamic> json) =>
      AttendanceLocationSite(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        radiusM: json['radius_m'] as int,
        maxAccuracyM: json['max_accuracy_m'] as int,
        isActive: json['is_active'] as bool,
        isVisible: json['is_visible'] as bool? ?? true,
      );
}

class AttendanceLocationAssignment {
  const AttendanceLocationAssignment({
    required this.siteId,
    required this.workerId,
  });
  final String siteId;
  final String workerId;
}

class AttendanceLocationAdminData {
  const AttendanceLocationAdminData({
    required this.sites,
    required this.workers,
    required this.assignments,
  });
  final List<AttendanceLocationSite> sites;
  final List<UserProfile> workers;
  final List<AttendanceLocationAssignment> assignments;
}

class AttendanceSyncLog {
  const AttendanceSyncLog({
    required this.attendanceId,
    required this.status,
    required this.attempts,
    required this.updatedAt,
    this.error,
    this.workDate,
    this.workerName,
  });
  final String attendanceId;
  final String status;
  final int attempts;
  final String updatedAt;
  final String? error;
  final String? workDate;
  final String? workerName;
}

class AttendanceRepository {
  AttendanceRepository(this._client);

  final SupabaseClient _client;

  Future<AttendanceRecord?> loadForDate(
    String workerId,
    String workDate,
  ) async {
    final row = await _client
        .from('attendance_records')
        .select('id,worker_id,work_date,check_in_at,check_out_at')
        .eq('worker_id', workerId)
        .eq('work_date', workDate)
        .maybeSingle();
    return row == null ? null : AttendanceRecord.fromJson(row);
  }

  Future<List<AttendanceRecord>> loadMonth({
    required String workerId,
    required String monthStart,
    required String monthEnd,
  }) async {
    final rows = await _client
        .from('attendance_records')
        .select('id,worker_id,work_date,check_in_at,check_out_at')
        .eq('worker_id', workerId)
        .gte('work_date', monthStart)
        .lte('work_date', monthEnd)
        .order('work_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => AttendanceRecord.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<TeamMemberAttendance>> loadActiveTeam(String workDate) async {
    final responses = await Future.wait<Object?>([
      _client
          .from('profiles')
          .select('id,full_name,role,is_active')
          .eq('role', 'worker')
          .eq('is_active', true)
          .order('full_name'),
      _client
          .from('attendance_records')
          .select('id,worker_id,work_date,check_in_at,check_out_at')
          .eq('work_date', workDate),
    ]);
    final profiles = responses[0] as List<dynamic>;
    final attendanceRows = responses[1] as List<dynamic>;
    final attendanceByWorker = <String, AttendanceRecord>{
      for (final row in attendanceRows)
        (row as Map<String, dynamic>)['worker_id'] as String:
            AttendanceRecord.fromJson(row),
    };
    return profiles.map((row) {
      final profile = UserProfile.fromJson(row as Map<String, dynamic>);
      return TeamMemberAttendance(
        profile: profile,
        record: attendanceByWorker[profile.id],
      );
    }).toList();
  }

  Future<List<TeamMemberHistory>> loadTeamMonth({
    required String monthStart,
    required String monthEnd,
  }) async {
    final responses = await Future.wait<Object?>([
      _client
          .from('profiles')
          .select('id,full_name,role,is_active')
          .eq('role', 'worker')
          .order('full_name'),
      _client
          .from('attendance_records')
          .select('id,worker_id,work_date,check_in_at,check_out_at')
          .gte('work_date', monthStart)
          .lte('work_date', monthEnd)
          .order('work_date', ascending: false),
    ]);
    final profiles = responses[0] as List<dynamic>;
    final rows = responses[1] as List<dynamic>;
    final grouped = <String, List<AttendanceRecord>>{};
    for (final row in rows) {
      final record = AttendanceRecord.fromJson(row as Map<String, dynamic>);
      grouped.putIfAbsent(record.workerId, () => []).add(record);
    }
    return profiles.map((row) {
      final profile = UserProfile.fromJson(row as Map<String, dynamic>);
      return TeamMemberHistory(
        profile: profile,
        records: grouped[profile.id] ?? const [],
      );
    }).toList();
  }

  Future<List<UserProfile>> loadCorrectionWorkers() async {
    final adminId = _client.auth.currentUser?.id;
    if (adminId == null) return const [];
    final rows = await _client
        .from('profiles')
        .select('id,full_name,role,is_active')
        .or('role.eq.worker,id.eq.$adminId')
        .eq('is_active', true)
        .order('full_name');
    return (rows as List<dynamic>)
        .map((row) => UserProfile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AttendanceAdjustment>> loadRecentAdjustments() async {
    final rows =
        await _client
                .from('attendance_adjustments')
                .select(
                  'worker_id,work_date,reason,old_check_in_at,old_check_out_at,new_check_in_at,new_check_out_at',
                )
                .order('created_at', ascending: false)
                .limit(12)
            as List<dynamic>;
    if (rows.isEmpty) return const [];
    final ids = rows
        .map((row) => (row as Map<String, dynamic>)['worker_id'] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('profiles')
        .select('id,full_name')
        .inFilter('id', ids);
    final names = {
      for (final row in profiles as List<dynamic>)
        (row as Map<String, dynamic>)['id'] as String:
            row['full_name'] as String? ?? 'Trabajador',
    };
    return rows.map((row) {
      final item = row as Map<String, dynamic>;
      return AttendanceAdjustment(
        workerName: names[item['worker_id']] ?? 'Trabajador',
        workDate: item['work_date'] as String,
        reason: item['reason'] as String,
        oldCheckInAt: item['old_check_in_at'] as String?,
        oldCheckOutAt: item['old_check_out_at'] as String?,
        newCheckInAt: item['new_check_in_at'] as String?,
        newCheckOutAt: item['new_check_out_at'] as String?,
      );
    }).toList();
  }

  Future<void> correctAttendance({
    required String workerId,
    required String workDate,
    required String? checkInAt,
    required String? checkOutAt,
    required String reason,
  }) async {
    await _client.rpc(
      'admin_correct_attendance',
      params: {
        'p_worker_id': workerId,
        'p_work_date': workDate,
        'p_check_in_at': checkInAt,
        'p_check_out_at': checkOutAt,
        'p_reason': reason,
      },
    );
  }

  Future<AttendanceLocationAdminData> loadLocationAdminData() async {
    final results = await Future.wait<Object?>([
      _client
          .from('attendance_location_sites')
          .select(
            'id,code,name,latitude,longitude,radius_m,max_accuracy_m,is_active,is_visible',
          )
          .eq('is_visible', true)
          .order('name'),
      _client
          .from('profiles')
          .select('id,full_name,role,is_active')
          .eq('role', 'worker')
          .eq('is_active', true)
          .order('full_name'),
      _client
          .from('attendance_location_site_workers')
          .select('site_id,worker_id'),
    ]);
    return AttendanceLocationAdminData(
      sites: (results[0] as List<dynamic>)
          .map(
            (row) =>
                AttendanceLocationSite.fromJson(row as Map<String, dynamic>),
          )
          .toList(),
      workers: (results[1] as List<dynamic>)
          .map((row) => UserProfile.fromJson(row as Map<String, dynamic>))
          .toList(),
      assignments: (results[2] as List<dynamic>)
          .map(
            (row) => AttendanceLocationAssignment(
              siteId: (row as Map<String, dynamic>)['site_id'] as String,
              workerId: row['worker_id'] as String,
            ),
          )
          .toList(),
    );
  }

  Future<String> saveLocationSite({
    required String? siteId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusM,
    required int maxAccuracyM,
    required bool isActive,
    required List<String> workerIds,
  }) async {
    final result = await _client.rpc(
      'save_attendance_location_site',
      params: {
        'p_site_id': siteId,
        'p_name': name,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_m': radiusM,
        'p_max_accuracy_m': maxAccuracyM,
        'p_is_active': isActive,
        'p_worker_ids': workerIds,
      },
    );
    return result as String;
  }

  Future<List<AttendanceSyncLog>> loadSyncLogs({int limit = 30}) async {
    final rows =
        await _client
                .from('sync_log')
                .select('attendance_id,status,error,intentos,updated_at')
                .order('updated_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    if (rows.isEmpty) return const [];
    final attendanceIds = rows
        .map((row) => (row as Map<String, dynamic>)['attendance_id'] as String)
        .toList();
    final attendanceRows =
        await _client
                .from('attendance_records')
                .select('id,worker_id,work_date')
                .inFilter('id', attendanceIds)
            as List<dynamic>;
    final attendanceById = <String, Map<String, dynamic>>{
      for (final row in attendanceRows)
        (row as Map<String, dynamic>)['id'] as String: row,
    };
    final workerIds = attendanceRows
        .map((row) => (row as Map<String, dynamic>)['worker_id'] as String)
        .toSet()
        .toList();
    final profiles = workerIds.isEmpty
        ? <dynamic>[]
        : await _client
                  .from('profiles')
                  .select('id,full_name')
                  .inFilter('id', workerIds)
              as List<dynamic>;
    final names = {
      for (final row in profiles)
        (row as Map<String, dynamic>)['id'] as String:
            row['full_name'] as String? ?? 'Trabajador',
    };
    return rows.map((row) {
      final log = row as Map<String, dynamic>;
      final attendance = attendanceById[log['attendance_id']];
      return AttendanceSyncLog(
        attendanceId: log['attendance_id'] as String,
        status: log['status'] as String,
        attempts: log['intentos'] as int? ?? 0,
        updatedAt: log['updated_at'] as String,
        error: log['error'] as String?,
        workDate: attendance?['work_date'] as String?,
        workerName: attendance == null
            ? null
            : names[attendance['worker_id']] ?? 'Trabajador',
      );
    }).toList();
  }

  Future<int> queueAttendanceResync({
    required String fromDate,
    required String toDate,
  }) async {
    final count = await _client.rpc(
      'queue_attendance_resync',
      params: {'p_from_date': fromDate, 'p_to_date': toDate},
    );
    return (count as num).toInt();
  }

  Future<AttendanceMarkResult> mark(Position position) async {
    final response = await _client.rpc(
      'record_attendance_with_location',
      params: {
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_accuracy_m': position.accuracy,
      },
    );
    return AttendanceMarkResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
