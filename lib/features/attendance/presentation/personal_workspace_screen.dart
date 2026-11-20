import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../data/attendance_record.dart';
import '../data/attendance_repository.dart';

class PersonalWorkspaceScreen extends StatefulWidget {
  const PersonalWorkspaceScreen({
    required this.profile,
    required this.onSignOut,
    super.key,
  });
  final UserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  State<PersonalWorkspaceScreen> createState() =>
      _PersonalWorkspaceScreenState();
}

class _PersonalWorkspaceScreenState extends State<PersonalWorkspaceScreen> {
  late final AttendanceRepository _repository = AttendanceRepository(
    Supabase.instance.client,
  );
  int _tab = 0;
  late DateTime _month = _peruNow;
  DateTime _clock = _peruNow;
  AttendanceRecord? _today;
  List<AttendanceRecord> _records = [];
  List<TeamMemberAttendance> _team = [];
  bool _teamLoading = false;
  String? _teamError;
  Timer? _timer;
  bool _loading = true;
  bool _attendanceLoadFailed = false;
  bool _marking = false;
  String? _error;

  static DateTime get _peruNow =>
      DateTime.now().toUtc().subtract(const Duration(hours: 5));
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _clock = _peruNow);
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final start = DateTime(_month.year, _month.month);
      final end = DateTime(_month.year, _month.month + 1, 0);
      final result = await Future.wait<Object?>([
        _repository.loadForDate(widget.profile.id, _dateKey(_peruNow)),
        _repository.loadMonth(
          workerId: widget.profile.id,
          monthStart: _dateKey(start),
          monthEnd: _dateKey(end),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _today = result[0] as AttendanceRecord?;
        _records = result[1] as List<AttendanceRecord>;
        _attendanceLoadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _attendanceLoadFailed = true;
          _error = 'No se pudo cargar tu asistencia. Revisa tu conexión y vuelve a actualizar.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTeam() async {
    setState(() {
      _teamLoading = true;
      _teamError = null;
    });
    try {
      final team = await _repository.loadActiveTeam(_dateKey(_peruNow));
      if (!mounted) return;
      setState(() {
        _team = team;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _teamError = 'No se pudo cargar el equipo. Revisa tu conexión y vuelve a actualizar.';
        });
      }
    } finally {
      if (mounted) setState(() => _teamLoading = false);
    }
  }

  Future<void> _refreshCurrentTab(bool admin) async {
    if (admin && _tab == 1) {
      await _loadTeam();
    } else {
      await _load();
    }
  }

  Future<void> _mark() async {
    if (_marking || _today?.checkOutAt != null) return;
    final eventName = _today?.checkInAt == null ? 'entrada' : 'salida';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined, color: AppColors.navy),
        title: Text('Registrar $eventName'),
        content: const Text(
          'Se consultará tu ubicación una vez para validar la marca. La app no rastrea tu ubicación en segundo plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Validar y marcar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _marking = true;
      _error = null;
    });
    try {
      final position = await _currentPosition();
      final result = await _repository.mark(position);
      if (!result.ok || result.record == null) {
        setState(() => _error = result.diagnosticMessage);
        return;
      }
      setState(() => _today = result.record);
      await _load(spinner: false);
      if (!mounted) return;
      final markedTime = result.event == 'check_out'
          ? result.record!.checkOutAt
          : result.record!.checkInAt;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xFF29976D),
            size: 42,
          ),
          title: const Text('Marca registrada'),
          content: Text(
            '${result.event == 'check_out' ? 'Salida' : 'Entrada'} · ${_time(markedTime)}${result.siteName == null ? '' : '\nSede: ${result.siteName}'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } on DeviceLocationOff {
      if (mounted) {
        setState(
          () =>
              _error = 'Activa la ubicación del teléfono e inténtalo otra vez.',
        );
      }
    } on DeviceLocationDenied catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'La ubicación tardó demasiado. Acércate a una ventana y vuelve a intentarlo.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo validar la ubicación. Revisa el GPS y tu conexión e inténtalo otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationOff();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DeviceLocationDenied(
        permission == LocationPermission.deniedForever
            ? 'El permiso está bloqueado. Actívalo para esta app desde Ajustes.'
            : 'Permite el acceso a la ubicación para validar tu asistencia.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 25),
      ),
    );
  }

  String _time(String? value) {
    if (value == null) return '—';
    final lima = DateTime.parse(value)
        .toUtc()
        .subtract(const Duration(hours: 5));
    return DateFormat('h:mm a', 'es_PE').format(lima);
  }

  String _duration(int minutes) =>
      '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} min';
  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  Future<void> _changeMonth(int amount) async {
    final next = DateTime(_month.year, _month.month + amount);
    final now = _peruNow;
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() {
      _month = next;
      _loading = true;
      _error = null;
    });
    await _load(spinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.profile.role == 'admin';
    final firstName = widget.profile.fullName.split(' ').first;
    Widget page;
    if (admin && _tab == 1) {
      page = _teamPage();
    } else if (admin && _tab == 2) {
      page = _historyPage();
    } else if (!admin && _tab == 1) {
      page = _historyPage();
    } else {
      page = _attendancePage(firstName, admin);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DK PARTNERS',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: (_loading || _teamLoading)
                ? null
                : () => _refreshCurrentTab(admin),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshCurrentTab(admin),
          child: page,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) {
          setState(() => _tab = value);
          if (admin && value == 1) {
            unawaited(_loadTeam());
          } else {
            unawaited(_load());
          }
        },
        destinations: admin
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.access_time_outlined),
                  selectedIcon: Icon(Icons.access_time_filled),
                  label: 'Mi asistencia',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Equipo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Mi Registro',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.access_time_outlined),
                  selectedIcon: Icon(Icons.access_time_filled),
                  label: 'Asistencia',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Mi Registro de Horas',
                ),
              ],
      ),
    );
  }

  Widget _attendancePage(String firstName, bool admin) {
    final started = _today?.checkInAt != null;
    final finished = _today?.checkOutAt != null;
    final stateColor = finished
        ? const Color(0xFF29976D)
        : started
        ? const Color(0xFFB77718)
        : AppColors.muted;
    final stateLabel = finished
        ? 'Jornada completa'
        : started
        ? 'EN CURSO'
        : 'Sin marcar';
    final date = _capitalize(DateFormat('EEEE d MMMM', 'es_PE').format(_clock));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        Text(
          admin ? 'REGISTRO PERSONAL · ADMINISTRACIÓN' : 'MI ASISTENCIA',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hola, $firstName',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 22),
        if (_error != null) ...[
          _ErrorCard(message: _error!),
          const SizedBox(height: 14),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ESTADO DE HOY',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stateLabel,
                        style: TextStyle(
                          color: stateColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'TIEMPO TRABAJADO',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _duration(_today?.workedMinutes ?? 0),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 20),
                _TimeRow(
                  label: 'ENTRADA',
                  value: _time(_today?.checkInAt),
                  complete: started,
                ),
                const SizedBox(height: 13),
                _TimeRow(
                  label: 'SALIDA',
                  value: _time(_today?.checkOutAt),
                  complete: finished,
                  pending: started && !finished,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed:
                      _loading || _marking || finished || _attendanceLoadFailed
                      ? null
                      : _mark,
                  icon: _marking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          finished
                              ? Icons.check_circle_outline
                              : Icons.location_on_outlined,
                        ),
                  label: Text(
                    _marking
                        ? 'Validando ubicación…'
                        : finished
                        ? 'Jornada completa'
                        : started
                        ? 'Marcar salida'
                        : 'Marcar entrada',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La ubicación se consulta solo al marcar. No se rastrea en segundo plano.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _teamPage() {
    final present = _team
        .where((member) => member.record?.checkInAt != null)
        .length;
    final complete = _team
        .where((member) => member.record?.checkOutAt != null)
        .length;
    final date = _capitalize(DateFormat('EEEE d MMMM', 'es_PE').format(_clock));
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
          'Asistencia del equipo',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'TRABAJADORES',
                value: '${_team.length}',
                subtitle: 'Cuentas activas',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'PRESENTES',
                value: '$present',
                subtitle: 'Con entrada',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          label: 'JORNADAS COMPLETAS',
          value: '$complete',
          subtitle: 'Trabajadores con entrada y salida',
          wide: true,
        ),
        const SizedBox(height: 18),
        if (_teamError != null) ...[
          _ErrorCard(message: _teamError!),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ESTADO DE HOY',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar equipo',
                      onPressed: _teamLoading ? null : _loadTeam,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_teamLoading) const LinearProgressIndicator(minHeight: 2),
                if (!_teamLoading && _team.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No hay trabajadores activos para mostrar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ..._team.map(_teamMemberCard),
                const SizedBox(height: 12),
                const Text(
                  'Tu asistencia como administrador se consulta en “Mi asistencia”.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamMemberCard(TeamMemberAttendance member) {
    final record = member.record;
    final hasEntry = record?.checkInAt != null;
    final complete = record?.checkOutAt != null;
    final label = complete
        ? 'Completa'
        : hasEntry
        ? 'En curso'
        : 'Sin marcar';
    final color = complete
        ? const Color(0xFF29976D)
        : hasEntry
        ? const Color(0xFFB77718)
        : AppColors.muted;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.navy.withValues(alpha: .1),
                child: Text(
                  member.profile.fullName.isEmpty
                      ? '?'
                      : member.profile.fullName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.profile.fullName,
                  style: const TextStyle(
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryTime(
                  label: 'ENTRADA',
                  value: _time(record?.checkInAt),
                ),
              ),
              Expanded(
                child: _HistoryTime(
                  label: 'SALIDA',
                  value: _time(record?.checkOutAt),
                ),
              ),
              Expanded(
                child: _HistoryTime(
                  label: 'HORAS',
                  value: _duration(record?.workedMinutes ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyPage() {
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1, 0);
    final marked = _records
        .where((record) => record.checkInAt != null)
        .toList();
    final complete = marked.where((record) => record.checkOutAt != null).length;
    final total = marked.fold<int>(
      0,
      (sum, record) => sum + record.workedMinutes,
    );
    final currentMonth = _monthKey(_peruNow);
    final monthName = _capitalize(
      DateFormat('MMMM yyyy', 'es_PE').format(start),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        const Text(
          'MI REGISTRO DE HORAS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tus asistencias',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'DÍAS MARCADOS',
                value: '${marked.length}',
                subtitle: 'Este mes',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'JORNADAS COMPLETAS',
                value: '$complete',
                subtitle: 'Con salida',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          label: 'HORAS REGISTRADAS',
          value: _duration(total),
          subtitle: 'Incluye la jornada de hoy en curso',
          wide: true,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mes anterior',
                      onPressed: _loading ? null : () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        monthName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mes siguiente',
                      onPressed:
                          _loading ||
                              _monthKey(end).compareTo(currentMonth) >= 0
                          ? null
                          : () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorCard(message: _error!),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  )
                else if (marked.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32, horizontal: 12),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 36,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Aún no tienes marcas registradas este mes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  )
                else
                  ...marked.map(_historyCard),
                const Divider(height: 22),
                const Text(
                  'Horario mostrado en hora de Perú · Solo tú puedes ver este registro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _historyCard(AttendanceRecord record) {
    final complete = record.checkOutAt != null;
    final date = DateTime.parse('${record.workDate}T12:00:00Z');
    final dateLabel = _capitalize(
      DateFormat('EEEE d MMM', 'es_PE').format(date),
    );
    final tint = complete ? const Color(0xFFDCEDE5) : const Color(0xFFF2E4C8);
    final bg = complete ? const Color(0xFFF6FAF8) : const Color(0xFFFFFAF1);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: tint),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppColors.navyDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                complete ? 'COMPLETA' : 'EN CURSO',
                style: TextStyle(
                  color: complete
                      ? const Color(0xFF29976D)
                      : const Color(0xFFB77718),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HistoryTime(
                  label: 'ENTRADA',
                  value: _time(record.checkInAt),
                ),
              ),
              Expanded(
                child: _HistoryTime(
                  label: 'SALIDA',
                  value: _time(record.checkOutAt),
                ),
              ),
              Expanded(
                child: _HistoryTime(
                  label: 'HORAS',
                  value: _duration(record.workedMinutes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeviceLocationOff implements Exception {
  const DeviceLocationOff();
}

class DeviceLocationDenied implements Exception {
  const DeviceLocationDenied(this.message);
  final String message;
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    this.complete = false,
    this.pending = false,
  });
  final String label;
  final String value;
  final bool complete;
  final bool pending;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        complete ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 19,
        color: complete
            ? const Color(0xFF29976D)
            : pending
            ? const Color(0xFFB77718)
            : AppColors.line,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.wide = false,
  });
  final String label;
  final String value;
  final String subtitle;
  final bool wide;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.navyDark,
              fontSize: wide ? 23 : 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _HistoryTime extends StatelessWidget {
  const _HistoryTime({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          letterSpacing: .6,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0EE),
      border: Border.all(color: const Color(0xFFF2D2CD)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: Color(0xFFA3443A),
        fontSize: 12,
        height: 1.45,
      ),
    ),
  );
}
