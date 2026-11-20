# Control Asistencia DK Partners Mobile

Aplicacion Flutter para adaptar a Android y iPhone el sistema de asistencia que ya funciona en la web. La experiencia y las reglas existentes se toman como referencia; Supabase continua siendo la fuente de verdad.

## Estado actual

- Estructura Flutter creada para Android e iOS.
- Tema y pantalla de acceso adaptados a los colores, logo y textos de la version web.
- La autenticacion y las operaciones de asistencia se conectaran en los siguientes commits.

## Stack

- Flutter y Dart para la app movil.
- Supabase para autenticacion, perfiles, asistencias, ubicaciones y RPC existentes.
- Firebase Cloud Messaging para notificaciones push.
- Supabase Cron y Edge Functions para programar recordatorios en el servidor.
- Google Sheets permanece como copia sincronizada desde el backend.

La app usara la clave publishable y respetara las politicas RLS. Nunca se incluiran la service role key ni credenciales privadas de Firebase en el cliente.

## Fases

1. **Base visual y navegacion:** scaffold Flutter, tema DK Partners y pantalla de acceso reutilizando el flujo web.
2. **Acceso y perfiles:** autenticacion Supabase, sesion, perfiles y navegacion por rol.
3. **Trabajador:** ubicacion, marcacion por la RPC existente e historial personal.
4. **Administrador:** panel, horarios del equipo, correcciones auditadas, ubicaciones y re-sincronizacion.
5. **Notificaciones:** tokens de dispositivos, permisos, FCM y recordatorios programados en Supabase.
6. **Validacion y publicacion:** pruebas en Android/iPhone y preparacion de compilaciones firmadas.

Cada fase se mantendra en commits pequenos y en espanol.

## Ejecutar en Android

Desde la raiz del repositorio:

```powershell
flutter pub get
flutter devices
flutter run
```

VS Code puede lanzar la app con F5 y aplicar hot reload durante el desarrollo. Esta primera pantalla es visual; el acceso real se conectara con Supabase en el siguiente paso.

Para compilar iOS se necesita macOS con Xcode.