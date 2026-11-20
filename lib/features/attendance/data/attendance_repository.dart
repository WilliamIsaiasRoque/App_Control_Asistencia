import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attendance_record.dart';

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
