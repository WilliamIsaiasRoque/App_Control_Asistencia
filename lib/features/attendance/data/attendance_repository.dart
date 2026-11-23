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
