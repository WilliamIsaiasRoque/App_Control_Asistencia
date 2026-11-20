# Control Asistencia DK Partners Mobile

Aplicacion movil para trabajadores y administracion de DK Partners. Este repositorio inicia la adaptacion a Flutter y busca dar soporte a Android y iOS con una interfaz pensada para telefono.

## Estado

Repositorio inicial. Las funciones se incorporaran por fases y commits pequenos. La aplicacion web actual se mantiene separada durante el desarrollo.

## Stack previsto

- Flutter y Dart para la aplicacion movil.
- Supabase para autenticacion, perfiles, asistencias, ubicaciones y funciones RPC existentes.
- Firebase Cloud Messaging para notificaciones push.
- Supabase Cron y Edge Functions para decidir y enviar recordatorios desde el servidor.
- Google Sheets sigue siendo una copia sincronizada desde el backend; la app movil no debe escribir directamente a la hoja.

La base de datos y las reglas de asistencia existentes en Supabase se conservan. La app debe usar la clave publishable y las politicas RLS; nunca debe incluir la service role key ni credenciales privadas de Firebase.

## Fases de desarrollo

1. **Base movil:** estructura Flutter, tema DK Partners, navegacion, configuracion por entorno y cliente Supabase.
2. **Acceso y experiencia del trabajador:** inicio de sesion, perfil, permisos de ubicacion, marcacion de entrada/salida mediante la RPC existente e historial personal.
3. **Panel del administrador:** resumen del equipo, horarios, correccion auditada de marcas, gestion de ubicaciones y re-sincronizacion de Google Sheets.
4. **Notificaciones:** registro seguro de dispositivos, permisos y sonido, envio por FCM y programacion en el backend. Los recordatorios deben detenerse al registrar salida; falta definir la hora limite para dejar de insistir.
5. **Verificacion y publicacion:** pruebas en dispositivos Android y iPhone, permisos, ubicaciones, sesiones, notificaciones y compilaciones firmadas.

Cada fase se dividira en commits pequenos para poder revisar y desplegar cambios de manera controlada.

## Desarrollo

Requisitos previstos: Flutter SDK, Dart, Android Studio con Android SDK y un dispositivo o emulador Android. Para compilar y publicar la version iOS se necesita macOS con Xcode.

Las credenciales locales deben configurarse fuera del repositorio. Se puede usar `.env.example` como plantilla sin secretos.