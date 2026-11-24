import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../data/attendance_repository.dart';
import 'admin_attendance_correction_screen.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({required this.onCorrectionSaved, super.key});
  final Future<void> Function() onCorrectionSaved;

  @override
  AdminToolsScreenState createState() => AdminToolsScreenState();
}

class AdminToolsScreenState extends State<AdminToolsScreen>
    with SingleTickerProviderStateMixin {
  final _correctionKey = GlobalKey<AdminAttendanceCorrectionScreenState>();
  final _locationKey = GlobalKey<AdminLocationManagementScreenState>();
  final _syncKey = GlobalKey<AdminSheetsSyncScreenState>();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  Future<void> refresh() async {
    switch (_tabs.index) {
      case 0:
        await _correctionKey.currentState?.refresh();
      case 1:
        await _locationKey.currentState?.refresh();
      case 2:
        await _syncKey.currentState?.refresh();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(icon: Icon(Icons.edit_calendar_outlined), text: 'Corrección'),
            Tab(icon: Icon(Icons.location_on_outlined), text: 'Sedes'),
            Tab(icon: Icon(Icons.sync_outlined), text: 'Google Sheets'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            AdminAttendanceCorrectionScreen(
              key: _correctionKey,
              onSaved: widget.onCorrectionSaved,
            ),
            AdminLocationManagementScreen(key: _locationKey),
            AdminSheetsSyncScreen(key: _syncKey),
          ],
        ),
      ),
    ],
  );
}

class AdminLocationManagementScreen extends StatefulWidget {
  const AdminLocationManagementScreen({super.key});

  @override
  AdminLocationManagementScreenState createState() =>
      AdminLocationManagementScreenState();
}

class AdminLocationManagementScreenState
    extends State<AdminLocationManagementScreen> {
  late final _repo = AttendanceRepository(Supabase.instance.client);
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController(text: '25');
  final _accuracy = TextEditingController(text: '25');
  List<AttendanceLocationSite> _sites = [];
  List<UserProfile> _workers = [];
  List<AttendanceLocationAssignment> _assignments = [];
  Set<String> _selectedWorkers = {};
  String? _siteId;
  bool _creating = false;
  bool _active = true;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    _accuracy.dispose();
    super.dispose();
  }

  void _clearEditor() {
    _name.clear();
    _latitude.clear();
    _longitude.clear();
    _radius.text = '25';
    _accuracy.text = '25';
    _selectedWorkers = {};
    _active = true;
  }

  void _selectSite(AttendanceLocationSite? site) {
    setState(() {
      _creating = site == null;
      _siteId = site?.id;
      _error = null;
      _notice = null;
      if (site == null) {
        _clearEditor();
      } else {
        _name.text = site.name;
        _latitude.text = site.latitude.toStringAsFixed(7);
        _longitude.text = site.longitude.toStringAsFixed(7);
        _radius.text = site.radiusM.toString();
        _accuracy.text = site.maxAccuracyM.toString();
        _active = site.isActive;
        _selectedWorkers = _assignments
            .where((assignment) => assignment.siteId == site.id)
            .map((assignment) => assignment.workerId)
            .toSet();
      }
    });
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.loadLocationAdminData();
      if (!mounted) return;
      setState(() {
        _sites = data.sites;
        _workers = data.workers;
        _assignments = data.assignments;
        if (!_creating) {
          final selected = _sites.where((site) => site.id == _siteId);
          final site = selected.isNotEmpty
              ? selected.first
              : (_sites.isEmpty ? null : _sites.first);
          _siteId = site?.id;
          if (site == null) {
            _clearEditor();
          } else {
            _name.text = site.name;
            _latitude.text = site.latitude.toStringAsFixed(7);
            _longitude.text = site.longitude.toStringAsFixed(7);
            _radius.text = site.radiusM.toString();
            _accuracy.text = site.maxAccuracyM.toString();
            _active = site.isActive;
            _selectedWorkers = data.assignments
                .where((assignment) => assignment.siteId == site.id)
                .map((assignment) => assignment.workerId)
                .toSet();
          }
        }
      });
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron cargar las sedes. Revisa la conexión y la configuración de Supabase.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Activa la ubicación del dispositivo e inténtalo otra vez.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Permite el acceso a la ubicación desde los ajustes.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(7);
        _longitude.text = position.longitude.toStringAsFixed(7);
        _notice =
            'Ubicación capturada con precisión aproximada de ${position.accuracy.round()} m. Confirma que estás en el local antes de guardar.';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError ? error.message : 'No se pudo obtener la ubicación. Activa GPS y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    final radius = int.tryParse(_radius.text.trim());
    final accuracy = int.tryParse(_accuracy.text.trim());
    if (_name.text.trim().length < 3 ||
        latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radius == null ||
        radius < 10 ||
        radius > 2000 ||
        accuracy == null ||
        accuracy < 10 ||
        accuracy > 1000 ||
        _selectedWorkers.isEmpty) {
      setState(
        () => _error = 'Completa nombre, coordenadas válidas, límites permitidos y al menos un trabajador.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final id = await _repo.saveLocationSite(
        siteId: _siteId,
        name: _name.text.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusM: radius,
        maxAccuracyM: accuracy,
        isActive: _active,
        workerIds: _selectedWorkers.toList(),
      );
      if (!mounted) return;
      setState(() {
        _siteId = id;
        _creating = false;
        _notice = 'Punto y trabajadores autorizados guardados correctamente.';
      });
      await refresh();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar el punto. Comprueba la conexión e inténtalo otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Puntos autorizados',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar sedes',
            onPressed: _loading || _busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const Text(
        'Cada trabajador puede marcar desde cualquiera de sus sedes asignadas, dentro del radio y la precisión configurados.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      if (_error != null) _AdminMessage(_error!, error: true),
      if (_notice != null) _AdminMessage(_notice!, error: false),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ubicaciones visibles',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _loading
                        ? null
                        : () => _selectSite(null),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              if (!_loading && _sites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No hay sedes visibles configuradas.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ..._sites.map((site) {
                final selected = !_creating && _siteId == site.id;
                final assigned = _assignments
                    .where((assignment) => assignment.siteId == site.id)
                    .length;
                return Card(
                  color: selected ? const Color(0xFFEFF3F9) : null,
                  child: ListTile(
                    leading: Icon(
                      selected ? Icons.location_on : Icons.location_on_outlined,
                      color: site.isActive ? AppColors.navy : AppColors.muted,
                    ),
                    title: Text(
                      site.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${site.isActive ? 'Activa' : 'Inactiva'} · radio ${site.radiusM} m · precisión ${site.maxAccuracyM} m · $assigned personas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : () => _selectSite(site),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _creating ? 'Nueva ubicación' : 'Editar ubicación',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                enabled: !_busy && !_loading,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nombre del punto',
                  hintText: 'Ej.: Calle Puno 564',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _loading ? null : _captureLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Capturar ubicación actual'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latitude,
                      enabled: !_busy && !_loading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitud'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _longitude,
                      enabled: !_busy && !_loading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitud'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _radius,
                      enabled: !_busy && !_loading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radio permitido (10–2000 m)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _accuracy,
                      enabled: !_busy && !_loading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precisión máxima (10–1000 m)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Trabajadores autorizados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (_workers.isEmpty)
                const Text(
                  'No hay trabajadores activos.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ..._workers.map(
                (worker) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _selectedWorkers.contains(worker.id),
                  title: Text(worker.fullName),
                  onChanged: _busy || _loading
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            _selectedWorkers.add(worker.id);
                          } else {
                            _selectedWorkers.remove(worker.id);
                          }
                        }),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: const Text('Punto activo para marcar'),
                onChanged: _busy || _loading
                    ? null
                    : (value) => setState(() => _active = value),
              ),
              FilledButton.icon(
                onPressed: _busy || _loading || _workers.isEmpty ? null : _save,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_busy ? 'Guardando…' : 'Guardar punto y permisos'),
              ),
              const SizedBox(height: 8),
              const Text(
                'La ubicación se consulta solo al marcar. Radio y precisión son filtros distintos.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class AdminSheetsSyncScreen extends StatefulWidget {
  const AdminSheetsSyncScreen({super.key});

  @override
  AdminSheetsSyncScreenState createState() => AdminSheetsSyncScreenState();
}

class AdminSheetsSyncScreenState extends State<AdminSheetsSyncScreen> {
  late final _repo = AttendanceRepository(Supabase.instance.client);
  DateTime _from = _peruNow;
  DateTime _to = _peruNow;
  List<AttendanceSyncLog> _logs = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  static DateTime get _peruNow =>
      DateTime.now().toUtc().subtract(const Duration(hours: 5));
  String _dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _repo.loadSyncLogs();
      if (mounted) setState(() => _logs = logs);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cargar el registro de sincronización. Revisa la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: _peruNow,
      locale: const Locale('es', 'PE'),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final date = DateTime(selected.year, selected.month, selected.day);
      if (from) {
        _from = date;
        if (_from.isAfter(_to)) _to = date;
      } else {
        _to = date;
        if (_to.isBefore(_from)) _from = date;
      }
    });
  }

  Future<void> _resync() async {
    final fromDate = _dateKey(_from);
    final toDate = _dateKey(_to);
    if (fromDate.compareTo(toDate) > 0) {
      setState(() => _error = 'El rango de fechas no es válido.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final count = await _repo.queueAttendanceResync(
        fromDate: fromDate,
        toDate: toDate,
      );
      if (mounted) {
        setState(
          () =>
              _notice = '$count registro(s) puestos en cola para sincronizar.',
        );
      }
      await refresh();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo solicitar la re-sincronización.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _status(String value) {
    switch (value) {
      case 'synced':
        return 'Sincronizado';
      case 'processing':
        return 'Enviando a Google Sheets';
      case 'error':
        return 'Error';
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'synced':
        return const Color(0xFF29976D);
      case 'error':
        return const Color(0xFFB4443D);
      case 'processing':
        return const Color(0xFFB77718);
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _logs
        .where(
          (log) =>
              log.status == 'pending' ||
              log.status == 'processing' ||
              log.status == 'error',
        )
        .length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Google Sheets',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar eventos',
              onPressed: _loading || _busy ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Supabase guarda primero las marcas. La cola vuelve a intentar los pendientes automáticamente.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        if (_error != null) _AdminMessage(_error!, error: true),
        if (_notice != null) _AdminMessage(_notice!, error: false),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateChoice(
                        title: 'Desde',
                        value: _from,
                        onTap: _busy ? null : () => _pickDate(from: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateChoice(
                        title: 'Hasta',
                        value: _to,
                        onTap: _busy ? null : () => _pickDate(from: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy || _loading ? null : _resync,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _busy
                        ? 'Poniendo en cola…'
                        : 'Re-sincronizar con Google Sheets',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La solicitud vuelve a poner en cola las asistencias del rango elegido; el envío ocurre en segundo plano.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Últimos eventos',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _PendingPill(count: pending),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (!_loading && _logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Todavía no hay registros en la cola.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ..._logs.take(20).map((log) {
                  final date = log.workDate == null
                      ? 'Asistencia'
                      : DateFormat(
                          'dd/MM/yyyy',
                          'es_PE',
                        ).format(DateTime.parse('${log.workDate}T12:00:00'));
                  final workerName = log.workerName ?? 'Trabajador';
                  final title = '$workerName · $date';
                  final attempts = log.attempts.toString();
                  final subtitle = log.error == null || log.error!.isEmpty
                      ? '${_status(log.status)} · intentos: $attempts'
                      : log.error!;
                  final stamp = DateFormat('dd/MM HH:mm', 'es_PE').format(
                    DateTime.parse(log.updatedAt)
                        .toUtc()
                        .subtract(const Duration(hours: 5)),
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.circle,
                      size: 10,
                      color: _statusColor(log.status),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_status(log.status)} · $subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      stamp,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({
    required this.title,
    required this.value,
    required this.onTap,
  });
  final String title;
  final DateTime value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 4),
        Text(DateFormat('dd/MM/yyyy', 'es_PE').format(value)),
      ],
    ),
  );
}

class _PendingPill extends StatelessWidget {
  const _PendingPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: count > 0 ? const Color(0xFFFFF1DC) : const Color(0xFFEAF5EF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        count > 0 ? 'Revisar cola · $count' : 'Operativa',
        style: TextStyle(
          color: count > 0 ? const Color(0xFF9A6817) : const Color(0xFF237554),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _AdminMessage extends StatelessWidget {
  const _AdminMessage(this.message, {required this.error});
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
