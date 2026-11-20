# Control de Asistencia DK Partners

App móvil Flutter para Android y iPhone, basada en la interfaz y las reglas del sistema web existente. Supabase continúa como fuente de verdad.

## Estado

- Base Flutter para Android e iOS.
- Pantalla de acceso adaptada del diseño web de DK Partners.
- Inicio de sesión con correo y contraseña mediante Supabase Auth.
- Lectura del perfil, rol y estado activo desde `profiles`.
- Casilla para mantener la sesión en el dispositivo.
- Siguiente: espacio de trabajo del trabajador con ubicación, marcación por RPC e historial.

## Tecnologías

- Flutter y Dart.
- Supabase Auth y base de datos con las políticas RLS ya existentes.
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
flutter run --dart-define-from-file=supabase.local.json
```

Si hay varios dispositivos, indica el ID:

```powershell
flutter run -d ID_DEL_TELEFONO --dart-define-from-file=supabase.local.json
```

En VS Code también puedes seleccionar el dispositivo y ejecutar la aplicación con F5. Para compilar iOS se necesita macOS con Xcode.

## Fases siguientes

1. Espacio de trabajo del trabajador: estado de hoy, marcación con geolocalización vía RPC e historial personal.
2. Panel móvil de administración: asistencias del equipo, correcciones auditadas, sedes y re-sincronización.
3. Notificaciones: permisos, registro de dispositivos, FCM y recordatorios programados.
4. Validación en Android/iOS y preparación de publicación.

Los commits del proyecto se mantienen pequeños y en español.