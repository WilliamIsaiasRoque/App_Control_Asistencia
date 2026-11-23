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
    final rows = await _client
        .from('profiles')
        .select('id,full_name,role,is_active')
        .eq('role', 'worker')
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
