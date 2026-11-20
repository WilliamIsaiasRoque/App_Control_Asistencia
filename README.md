# Control de Asistencia DK Partners

App móvil Flutter para Android y iPhone, basada en la interfaz y las reglas del sistema web existente. Supabase continúa como fuente de verdad.

## Estado

- Pantalla de acceso con Supabase Auth, perfil, rol y sesión persistente opcional.
- Espacio personal: estado de hoy, entrada/salida con permiso de ubicación durante el uso e historial mensual.
- La marca se envía a la RPC `record_attendance_with_location`; las sedes, el radio y la precisión se validan en Supabase.
- El administrador ve y registra su asistencia propia; el backend la excluye de Google Sheets.
- El administrador ya tiene una pestaña de equipo con el estado diario de cada trabajador activo.
- Siguiente: historial del equipo y herramientas de corrección, sedes y re-sincronización.

## Tecnologías

- Flutter y Dart.
- Supabase Auth, perfiles, asistencias y políticas RLS ya existentes.
- Geolocator: ubicación consultada solo al marcar, sin seguimiento en segundo plano.
- Firebase Cloud Messaging y Supabase Cron/Edge Functions para una fase posterior de notificaciones.
- Google Sheets sigue sincronizándose desde el backend; la app no escribe directamente en la hoja.

## Configuración local de Supabase

Crea en la raíz del proyecto un archivo `supabase.local.json` con la URL del proyecto y su clave **publishable** (o la clave `anon` heredada):

```json
{
  "SUPABASE_URL": "https://tu-proyecto.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

Este archivo está excluido de Git. No uses ni guardes aquí la clave `service_role` o una clave secreta.

## Ejecutar en Android

Desde la raíz del repositorio, con un teléfono conectado y autorizado para depuración USB:

```powershell
flutter pub get
flutter devices
flutter run -d ID_DEL_TELEFONO --dart-define-from-file=supabase.local.json
```

Al marcar, la app pedirá ubicación en primer plano y mostrará una confirmación antes de llamar a Supabase. La acción genera o actualiza una asistencia real en el proyecto configurado. No se han añadido escrituras automáticas de prueba.

Para reducir el uso de C: puedes mantener la caché en D: en la terminal de VS Code:

```powershell
$env:PUB_CACHE = "D:\flutter\pub-cache"
$env:GRADLE_USER_HOME = "D:\flutter\gradle-cache"
```

En VS Code también puedes seleccionar el dispositivo y ejecutar la aplicación con F5. Para compilar iOS se necesita macOS con Xcode.

## Fases siguientes

1. Completar el panel del administrador: historial del equipo, correcciones auditadas, sedes y re-sincronización.
2. Notificaciones: registro de dispositivos, FCM y recordatorios programados.
3. Validación en Android/iOS y preparación de publicación.

Los commits del proyecto se mantienen pequeños y en español.