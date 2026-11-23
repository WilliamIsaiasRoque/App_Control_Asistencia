import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../data/attendance_repository.dart';

class AdminAttendanceCorrectionScreen extends StatefulWidget {
  const AdminAttendanceCorrectionScreen({required this.onSaved, super.key});
  final Future<void> Function() onSaved;
  @override
  AdminAttendanceCorrectionScreenState createState() =>
      AdminAttendanceCorrectionScreenState();
}

class AdminAttendanceCorrectionScreenState
    extends State<AdminAttendanceCorrectionScreen> {
  late final _repo = AttendanceRepository(Supabase.instance.client);
  final _reason = TextEditingController();
  List<UserProfile> _workers = [];
  List<AttendanceAdjustment> _adjustments = [];
  String? _workerId;
  DateTime _date = _peruNow;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  bool _loading = true;
  bool _recordLoading = false;
  bool _saving = false;
  String? _error;
  String? _notice;

  static DateTime get _peruNow =>
      DateTime.now().toUtc().subtract(const Duration(hours: 5));
  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait<Object?>([
        _repo.loadCorrectionWorkers(),
        _repo.loadRecentAdjustments(),
      ]);
      if (!mounted) return;
      _workers = data[0] as List<UserProfile>;
      _adjustments = data[1] as List<AttendanceAdjustment>;
      if (_workerId == null || !_workers.any((w) => w.id == _workerId)) {
        _workerId = _workers.isEmpty ? null : _workers.first.id;
      }
      await _loadRecord();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cargar la información. Revisa tu conexión y actualiza.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecord() async {
    final id = _workerId;
    if (id == null) {
      setState(() {
        _inTime = null;
        _outTime = null;
      });
      return;
    }
    setState(() {
      _recordLoading = true;
      _error = null;
      _notice = null;
    });
    try {
      final record = await _repo.loadForDate(id, _dateKey(_date));
      if (!mounted) return;
      setState(() {
        _inTime = _fromTimestamp(record?.checkInAt);
        _outTime = _fromTimestamp(record?.checkOutAt);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo leer esa asistencia.');
    } finally {
      if (mounted) setState(() => _recordLoading = false);
    }
  }

  TimeOfDay? _fromTimestamp(String? value) {
    if (value == null) return null;
    final t = DateTime.parse(value).toUtc().subtract(const Duration(hours: 5));
    return TimeOfDay(hour: t.hour, minute: t.minute);
  }

  String _timeText(TimeOfDay? t) {
    if (t == null) return 'Sin registrar';
    final hours = t.hour.toString().padLeft(2, '0');
    final minutes = t.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String? _toTimestamp(TimeOfDay? t) {
    if (t == null) return null;
    return DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      t.hour,
      t.minute,
    ).add(const Duration(hours: 5)).toIso8601String();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: _peruNow,
      locale: const Locale('es', 'PE'),
    );
    if (selected == null || !mounted) return;
    setState(
      () => _date = DateTime(selected.year, selected.month, selected.day),
    );
    await _loadRecord();
  }

  Future<void> _pickTime(bool isEntry) async {
    final current = isEntry ? _inTime : _outTime;
    final selected = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isEntry) {
        _inTime = selected;
      } else {
        _outTime = selected;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final id = _workerId;
    final reason = _reason.text.trim();
    if (id == null) return;
    if (reason.length < 5) {
      setState(
        () => _error =
            'Escribe el motivo de la corrección (mínimo 5 caracteres).',
      );
      return;
    }
    if (_outTime != null && _inTime == null) {
      setState(
        () => _error =
            'Para registrar una salida también debes indicar la entrada.',
      );
      return;
    }
    if (_inTime != null &&
        _outTime != null &&
        _outTime!.hour * 60 + _outTime!.minute <
            _inTime!.hour * 60 + _inTime!.minute) {
      setState(() => _error = 'La salida no puede ser anterior a la entrada.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await _repo.correctAttendance(
        workerId: id,
        workDate: _dateKey(_date),
        checkInAt: _toTimestamp(_inTime),
        checkOutAt: _toTimestamp(_outTime),
        reason: reason,
      );
      _reason.clear();
      await refresh();
      await widget.onSaved();
      if (mounted) {
        setState(
          () => _notice = 'Corrección guardada en Supabase y puesta en cola para Google Sheets.',
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar la corrección.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _auditTime(String? value) => _timeText(_fromTimestamp(value));

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        const Text(
          'ADMINISTRACIÓN',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Corregir asistencia',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ajusta una marca, indica el motivo y deja el cambio auditado.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (_error != null) _CorrectionMessage(_error!, error: true),
        if (_notice != null) _CorrectionMessage(_notice!, error: false),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(_workerId),
                  initialValue: _workerId,
                  decoration: const InputDecoration(
                    labelText: 'Trabajador',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: _workers
                      .map(
                        (worker) => DropdownMenuItem(
                          value: worker.id,
                          child: Text(worker.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: _saving || _recordLoading
                      ? null
                      : (value) {
                          setState(() => _workerId = value);
                          unawaited(_loadRecord());
                        },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving || _recordLoading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    'Fecha · ${DateFormat('dd/MM/yyyy', 'es_PE').format(_date)}',
                  ),
                ),
                if (_loading || _recordLoading)
                  const LinearProgressIndicator(minHeight: 2),
                _TimePickerRow(
                  label: 'Entrada',
                  value: _timeText(_inTime),
                  onPick: _saving || _recordLoading
                      ? null
                      : () => _pickTime(true),
                  onClear: _saving || _recordLoading
                      ? null
                      : () => setState(() => _inTime = null),
                ),
                _TimePickerRow(
                  label: 'Salida',
                  value: _timeText(_outTime),
                  onPick: _saving || _recordLoading
                      ? null
                      : () => _pickTime(false),
                  onClear: _saving || _recordLoading
                      ? null
                      : () => setState(() => _outTime = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 3,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la corrección',
                    hintText: 'Ej.: marcó tarde por una emergencia',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      _saving || _loading || _recordLoading || _workerId == null
                      ? null
                      : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar corrección'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hora de Perú (UTC−5). Deja ambas horas vacías para limpiar las marcas.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Últimas correcciones',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (!_loading && _adjustments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Aún no hay correcciones registradas.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ..._adjustments.map(
          (item) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.workerName} · ${DateFormat('dd/MM/yyyy', 'es_PE').format(DateTime.parse('${item.workDate}T12:00:00'))}',
                    style: const TextStyle(
                      color: AppColors.navyDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_auditTime(item.oldCheckInAt)} / ${_auditTime(item.oldCheckOutAt)} → ${_auditTime(item.newCheckInAt)} / ${_auditTime(item.newCheckOutAt)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  const _TimePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });
  final String label;
  final String value;
  final VoidCallback? onPick;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Elegir hora',
          onPressed: onPick,
          icon: const Icon(Icons.schedule),
        ),
        IconButton(
          tooltip: 'Limpiar hora',
          onPressed: onClear,
          icon: const Icon(Icons.clear),
        ),
      ],
    ),
  );
}

class _CorrectionMessage extends StatelessWidget {
  const _CorrectionMessage(this.message, {required this.error});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF0EE) : const Color(0xFFEAF5EF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: error ? const Color(0xFFA3443A) : const Color(0xFF237554),
        fontSize: 12,
      ),
    ),
  );
}
