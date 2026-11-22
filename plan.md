# Tarjet Fidel — Plan de implementación

## Arquitectura

- Código fuente **único** para todos los negocios; cada negocio usa su propio proyecto Firebase.
- Lo único que cambia por negocio: `firebase.web.json` (credenciales locales, ignoradas por git), el proyecto de `.firebaserc` y la configuración de `config/main`.
- Las credenciales se inyectan al compilar con `--dart-define-from-file=firebase.web.json`; `lib/firebase_options.dart` no contiene secretos.
- **Solo plan gratuito Spark**: sin Cloud Functions, sin Firebase Storage, sin cuenta de facturación.
- La lógica de negocio vive en transacciones de Firestore del cliente; **las reglas de Firestore son la autoridad anti-fraude**.

## Stack

- **Frontend**: Flutter Web (Dart, null safety).
- **Backend**: Firebase Auth, Firestore, Remote Config, Hosting y reglas de seguridad.
- **Paquetes**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_remote_config`, `firebase_app_check`, `qr_flutter`, `mobile_scanner`, `flutter_animate`, `file_picker`, `intl`.

## Interfaz y animaciones

- `flutter_animate` más un kit propio en `lib/widgets/app_animations.dart` y `lib/widgets/confetti_burst.dart`.
- `Reveal` y `StaggeredReveal` para entradas suaves y listas escalonadas.
- `HoverLift` y `Pulse` para tarjetas, insignias y avisos.
- `ShimmerHighlight` para el código de check-in y el logo.
- `AnimatedIndexedStack` para cambiar de pestaña sin perder estado.
- `ConfettiBurst` y `CelebrationOnChange` al aprobar solicitudes, canjear premios o subir sellos.
- `BrandBackground` anima el degradado y las luces del login, splash y bloqueo.
- `ConfigMetaSync` sincroniza el título, la descripción y el `theme-color` del navegador con `config/main`.

## Flujo de autenticación

### Administrador

- Correo y contraseña reales.
- El rol se determina por el documento `admins/{uid}`; no se usan claims.
- Un documento sin `role` se considera administrador del negocio.
- El primer administrador se crea desde la consola; los adicionales los da de alta el superadministrador desde **Plataforma**.
- El administrador puede pedir un enlace de restablecimiento de contraseña desde el login; los clientes no reciben correo porque usan un correo sintético.
- No puede modificar la fecha de la prueba ni crear otros administradores.

### Superadministrador

- Es el dueño de la plataforma (programador): `admins/{uid}.role = "superadmin"`.
- Tiene todas las funciones del administrador del negocio y una pestaña adicional, **Plataforma**.
- Puede entrar al panel aunque la prueba esté vencida para poder renovarla.
- Desde **Plataforma** consulta el estado, la fecha local, el valor UTC y el tiempo restante; puede fijar fecha/hora, sumar +7/+15/+30/+90 días o quitar el límite.
- Desde **Plataforma → Administradores de negocio** crea cuentas adicionales con correo real (se rechazan `.local`), nombre visible y contraseña de al menos 8 caracteres con letras y números.
- El alta usa una app secundaria de Firebase Auth para no cerrar su sesión; si falla el documento `admins/{uid}`, se elimina la cuenta creada.
- Solo él puede escribir los campos `trial*` de `config/main` y gestionar la colección `admins`, siempre con `role: "admin"`.

### Cliente

- Se registra con un nombre de usuario único y una contraseña de exactamente 6 dígitos.
- Internamente se usa el correo sintético `cliente_<usuario>@tarjetfidel.local`.
- Validación del usuario: `^[a-zA-Z0-9](?:[a-zA-Z0-9._-]{2,31})$`, nombre visible de hasta 60 caracteres.
- Registro en el cliente: `createUserWithEmailAndPassword` + transacción (`users/{uid}`, `usernames/{username}`, incremento de `counters/clients`). Si falla la transacción, se elimina la cuenta de Auth.

## Modelo de datos

### `config/main`

`businessName`, `logoUrl`, `stampsGoal`, `rewardDescription`, `themeColor`, `maxUsers`, `checkinCode`, `contactInfo`, `trialExpiryDate`, `trialExpiryAt`, `trialUpdatedAt`, `trialUpdatedBy`.

### `users/{uid}`

`username`, `usernameLower`, `internalEmail`, `displayName`, `currentStamps`, `totalVisits`, `role` (`client`), `isRewardReady`, `createdAt`, `updatedAt`.

### `stamp_requests/{id}`

`userId`, `userName`, `status` (`pending` / `approved` / `rejected`), `stampsAwarded`, `code`, `createdAt`, `approvedAt`, `approvedBy`, `rejectedAt`, `rejectedBy`, `updatedAt`.

### `visits/{id}`

`userId`, `stamps`, `approvedBy`, `requestId`, `timestamp`. Historial inmutable.

### `redemptions/{id}`

`userId`, `userName`, `stampsBefore`, `rewardDescription`, `redeemedBy`, `timestamp`.

### Colecciones de control

- `pending_requests/{uid}`: una sola solicitud pendiente por cliente.
- `rate_limits/{uid}`: `count`, `windowStart` (ventana de 24 h, máximo 10).
- `counters/clients`: `count`, comparado con `maxUsers`.
- `usernames/{username}`: reserva atómica del nombre de usuario.
- `admins/{uid}`: `email`, `displayName`, `role` (`admin` / `superadmin`; ausente = admin), `createdAt`, `updatedAt`.

## Operaciones de negocio (transacciones del cliente)

### Registro de cliente

- Verifica la prueba con `config/main.trialExpiryAt` y el límite con `counters/clients`.
- Crea `users/{uid}`, `usernames/{username}` e incrementa `counters/clients` de forma atómica.

### Solicitud de sello (`createStampRequest`)

- Normaliza el código (`TARJET:XXXX`, URL con `?code=` o código directo).
- Comprueba que coincida con `config/main.checkinCode`.
- Rechaza si ya hay una solicitud pendiente (anti-duplicado).
- Aplica el rate limit de 10 solicitudes cada 24 horas.
- Crea `stamp_requests` en estado `pending` y `pending_requests/{uid}` en la misma transacción. **El QR nunca otorga sellos.**

### Aprobación (`approveStampRequest`, admin)

- La solicitud debe estar `pending`.
- Suma los sellos indicados (1–10), incrementa `totalVisits`, actualiza `isRewardReady`.
- Crea `visits`, marca la solicitud como `approved` y borra `pending_requests/{uid}`.

### Rechazo (`rejectStampRequest`, admin)

- Marca la solicitud como `rejected` y borra `pending_requests/{uid}`.

### Canje (`resetStamps`, admin)

- Reinicia `currentStamps` y `isRewardReady`, y crea un registro en `redemptions`.

### Estado de la prueba (`checkTrialStatus`)

- Lee `config/main.trialExpiryAt` (Timestamp) y cae en `trialExpiryDate` (ISO) para configuraciones antiguas.
- Solo si Firestore no tiene fecha consulta `trial_expiry_date` de Remote Config como respaldo.
- Si no hay fecha válida, la prueba se considera activa.
- `AuthGate` escucha `config/main` en tiempo real y programa un `Timer` exacto para el vencimiento.

## Reglas de seguridad

- `config`: lectura pública. El administrador puede crear la configuración inicial y actualizar los campos del negocio sin tocar `trialExpiryAt`, `trialExpiryDate`, `trialUpdatedAt` ni `trialUpdatedBy`; borrar o modificar la prueba queda reservado al superadministrador.
- `users`: el cliente crea una sola vez su perfil con contadores a cero y correo coherente; después solo cambia `displayName`/`updatedAt`. El admin puede cambiar cualquier campo. Nadie borra.
- `usernames`: creación en la misma transacción que el perfil; sin update ni delete.
- `counters/clients`: incrementos de uno en uno, sin superar `maxUsers`, ligados a la creación del perfil mediante `getAfter()`.
- `stamp_requests`: el cliente solo crea solicitudes `pending` con el código vigente y su `pending_requests/{uid}` asociado; solo el admin aprueba/rechaza con 1–10 sellos.
- `pending_requests`: el cliente crea la suya; el admin la borra al resolver.
- `rate_limits`: el cliente solo incrementa hasta 10 o reinicia la ventana al pasar 24 horas.
- `visits` y `redemptions`: escritura solo admin; lectura del propio cliente o del admin (redemptions solo admin).
- `admins`: cada usuario comprueba su propio documento; solo el superadmin los lista y crea/edita/borra admins con `role: "admin"`, sin poder crear superadmins ni tocar su propia cuenta.

> `getAfter()` es obligatorio para comprobar escrituras de la misma transacción: `exists()` y `get()` no ven los cambios aún no confirmados.

## Prueba de 15 días

- `config/main.trialExpiryAt` (Timestamp) es la fuente de verdad; `trialExpiryDate` (ISO 8601) es su espejo legible.
- `trial_expiry_date` en Remote Config queda solo como respaldo para instalaciones sin fecha en Firestore.
- Al expirar, la app muestra la pantalla de bloqueo con los datos de contacto y las reglas rechazan las escrituras de los clientes.
- El superadministrador renueva desde la pestaña **Plataforma**; no hace falta recompilar ni redesplegar. El cambio llega en tiempo real a clientes y al panel del negocio.
- Las reglas impiden que el administrador del negocio modifique los campos `trial*`.

## Seguridad anti-fraude

- El QR no otorga sellos: solo crea solicitudes que el admin aprueba.
- Rate limit, anti-duplicado y límite de usuarios verificados por las reglas, no solo por la app.
- El cliente no puede escribir sellos, historial, canjes ni configuración.
- App Check con reCAPTCHA v3 es opcional (`RECAPTCHA_SITE_KEY`); no está registrado.
- La lectura pública de `config` expone el código de check-in, que se considera público (está en el mostrador).

## Checklist de verificación e implementación

### Fase 1: Configuración inicial

- [x] Estructura de proyecto Flutter Web
- [x] Firebase CLI y hosting (`firebase.json`, `.firebaserc`)
- [x] Paquetes de Firebase (sin `cloud_functions` ni `firebase_storage`)
- [x] Reglas de seguridad Firestore (`firestore.rules`)
- [x] App Check opcional con `RECAPTCHA_SITE_KEY`

### Fase 2: Autenticación y roles

- [x] Auth admin (correo/contraseña)
- [x] Auth cliente (usuario + contraseña de 6 dígitos, correo sintético)
- [x] Documento `admins/{uid}` como única fuente del rol
- [x] Rol `superadmin` en `admins/{uid}.role` con compatibilidad para documentos sin `role`
- [x] Validación de contraseña de 6 dígitos
- [x] Generación del correo interno `cliente_<usuario>@tarjetfidel.local`
- [x] Rollback de la cuenta de Auth si falla el perfil

### Fase 3: Modelo de datos y Firestore

- [x] `config/main`
- [x] `users`, `stamp_requests`, `visits`, `admins`, `redemptions`
- [x] `pending_requests`, `rate_limits`, `counters/clients`, `usernames`
- [x] Índices compuestos (`firestore.indexes.json`)
- [x] Reglas probadas contra el proyecto real

### Fase 4: Operaciones de negocio

- [x] `registerClientProfile` (transacción)
- [x] `createStampRequest` (transacción)
- [x] `approveStampRequest` (transacción, admin)
- [x] `rejectStampRequest` (transacción, admin)
- [x] `resetStamps` (transacción, admin)
- [x] `checkTrialStatus` (Firestore como fuente de verdad + Remote Config de respaldo)
- [x] Rate limit y anti-duplicado en cliente **y** reglas

### Fase 5: Flujo cliente

- [x] Pantalla de registro/login
- [x] Tarjeta de sellos con animación
- [x] Escáner QR con fallback manual
- [x] Estados `pending`, `approved`, `rejected`
- [x] Actualizaciones en tiempo real con `snapshots()`

### Fase 6: Flujo administrador

- [x] Login admin
- [x] Solicitudes pendientes en tiempo real
- [x] Aprobar/rechazar con cantidad de sellos editable
- [x] Configuración (nombre, logo, meta, premio, color, límite, contacto)
- [x] Logo en base64 (sin Storage)
- [x] QR de check-in
- [x] Actualizaciones sin recargar

### Fase 7: Prueba y despliegue

- [x] Remote Config con `trial_expiry_date` (respaldo)
- [x] Firestore como fuente de verdad de la prueba (`trialExpiryAt`)
- [x] Pantalla de bloqueo por expiración
- [x] Hosting desplegado
- [x] Administrador creado
- [x] `flutter analyze`, `flutter test` y `flutter build web` correctos
- [x] Reglas verificadas de extremo a extremo con el SDK cliente
- [x] Documentación de replicación

### Fase 8: Replicación por negocio

- [x] Checklist para crear el proyecto Firebase
- [x] Checklist para activar servicios (sin Functions ni Storage)
- [x] Checklist para Remote Config (respaldo opcional)
- [x] Checklist para credenciales (`firebase.web.json` + `tool/configure_firebase.mjs`)
- [x] Checklist para desplegar reglas e índices
- [x] Checklist para crear el primer admin
- [x] Checklist para compilar y desplegar hosting
- [x] Checklist para probar el negocio

### Fase 9: Animaciones y replicación limpia

- [x] Kit de animaciones (`Reveal`, `HoverLift`, `Pulse`, `ShimmerHighlight`, `StaggeredReveal`, `AnimatedIndexedStack`)
- [x] Confeti al aprobar, canjear y subir sellos
- [x] Fondo de marca animado y tema dinámico desde `config/main`
- [x] Título y `theme-color` del navegador sincronizados
- [x] Credenciales fuera del repositorio (`firebase.web.json` ignorado)
- [x] Asistente `tool/configure_firebase.mjs`
- [x] CI de GitHub Actions con `firebase.web.example.json`
- [x] Recuperación de contraseña del administrador

### Fase 10: Superadministrador y gestión de la prueba

- [x] Enum `AdminRole` y lectura de `admins/{uid}.role`
- [x] Utilidades de fecha y textos de prueba (`lib/utils/trial.dart`)
- [x] `ConfigModel.trialExpiry` normalizado a UTC
- [x] Pestaña **Plataforma** con estado, fecha local/UTC y tiempo restante
- [x] Selector de fecha/hora, botones +7/+15/+30/+90 días y opción sin límite
- [x] `AuthGate` reactivo a `config/main` con temporizador exacto de vencimiento
- [x] Acceso del superadministrador aunque la prueba esté vencida
- [x] Reglas: solo el superadministrador escribe los campos `trial*`
- [x] El guardado de configuración del negocio no toca los campos `trial*`
- [x] Chip de estado de prueba en la barra del panel
- [x] Pruebas de `trial.dart`, `ConfigModel.trialExpiry` y modelos (34 en total)
- [x] Crear la cuenta real del superadministrador y verificar el login y la renovación en producción (REST: login, rol, escritura de prueba y bloqueo al admin del negocio)

### Fase 11: Alta de administradores de negocio por el superadministrador

- [x] `AdminAccount` y `AdminRole` para el modelo y la distinción de roles
- [x] Validadores de correo real (sin `.local`), nombre visible y contraseña
- [x] `AdminManagementService` con app secundaria de Auth, rollback y traducción de errores
- [x] Sección **Administradores de negocio** en la pestaña **Plataforma** con formulario y listado en tiempo real
- [x] Reglas de `admins`: crear/listar/actualizar/borrar solo superadmin, sin escalada a `superadmin` ni auto-modificación
- [x] Pruebas de validación (6 nuevas; 40 en total)
- [x] Verificación REST en producción: 7/7 comprobaciones correctas y limpieza de documentos temporales

## Estado de implementación

Verificado y desplegado:

- `flutter analyze` → sin incidencias.
- `flutter test` → 40 pruebas superadas (modelos, códigos, fechas de prueba, validación de admins, animaciones y accesibilidad).
- `flutter build web --release --no-wasm-dry-run --dart-define-from-file=firebase.web.json` → compilación correcta.
- Proyecto Firebase de referencia creado y app web registrada.
- Credenciales reales en `firebase.web.json` (ignorado por git); `lib/firebase_options.dart` las lee por `dart-define`.
- Authentication (correo/contraseña) activo.
- Firestore (base con nombre `default`) con reglas e índices desplegados.
- Remote Config `trial_expiry_date` publicado (versión 1).
- Administrador de referencia con documento `admins/{uid}`; inicio de sesión verificado.
- `config/main` sembrada; `counters/clients` en 0.
- Hosting de referencia desplegado.

Superadministrador y prueba:

- `AdminRole` interpreta `admins/{uid}.role`; los documentos sin `role` siguen siendo administradores del negocio.
- La pestaña **Plataforma** solo aparece para `role: "superadmin"` y permite fijar fecha/hora, sumar días o quitar el límite.
- `AuthGate` prioriza Firestore y reacciona a `config/main` en tiempo real; al renovar, los clientes se desbloquean sin recargar.
- Las reglas protegen los campos `trial*` y `saveConfig` los elimina del guardado normal del negocio.
- El superadministrador entra al panel aunque la prueba esté vencida.
- Cuenta de superadministrador creada y verificada por REST: login, `role: "superadmin"`, lectura de `config/main`, escritura de `trial*` permitida y escritura de `trial*` denegada al administrador del negocio.

Alta de administradores:

- El superadministrador crea administradores de negocio desde **Plataforma → Administradores de negocio**; la sesión privilegiada no se pierde porque la cuenta de Auth se crea en una app secundaria.
- Los correos `.local` se rechazan en el formulario para no confundir admins con clientes sintéticos; la contraseña exige letras y números.
- Si falla la escritura de `admins/{uid}`, se intenta borrar la cuenta de Auth creada y se muestra el error traducido al usuario.
- Las reglas de `admins` permiten al superadmin crear/listar/editar/borrar solo cuentas `role: "admin"`; le impiden crear superadmins, borrar su propio documento y modificar otros superadmins. El admin del negocio no puede listar ni escribir en `admins`.
- Verificación REST en producción (7/7): crear admin, leerlo, actualizarlo y borrarlo como superadmin → permitido; crear admin o listar como negocio → denegado; crear superadmin o borrar la propia cuenta → denegado. Los documentos temporales se eliminaron.

Mejoras de interfaz y accesibilidad:

- `AnimatedIndexedStack` mantiene el ticker de la pestaña saliente durante el fundido y lo apaga al terminar, sin dejar capas visibles.
- Todas las animaciones decorativas respetan `MediaQuery.disableAnimations` (movimiento reducido): entrada, pulso, brillo, confeti, fondo de marca, progreso y transiciones.
- El estado «premio listo» se calcula con la meta actual (`UserModel.isRewardReadyFor`), así que cambiar `stampsGoal` no deja insignias desfasadas.
- El canje avisa si el cliente aún no completó la tarjeta antes de reiniciar sus sellos.
- `approveStampRequest` rechaza valores fuera de 1–10 en lugar de recortarlos en silencio.
- Los errores de guardado de configuración muestran el mensaje de `AppFailure` cuando existe.

Verificación de reglas (SDK cliente, proyecto real):

- Registro de cliente, solicitud de sello y aprobación por el admin → correcto.
- El cliente no puede aprobar su propia solicitud, editar sus sellos, crear historial, leer otros perfiles, editar la configuración ni borrar su solicitud pendiente → `permission-denied`.
- Código incorrecto, estado distinto de `pending`, sellos distintos de 1 y solicitud a nombre de otro usuario → `permission-denied`.
- Aprobar con 11 sellos → `permission-denied`; con 2 sellos → correcto.
- Canje del premio → correcto.
- Prueba vencida (`trialExpiryAt` en el pasado) bloquea las solicitudes de clientes → verificado y restaurado.
- Los datos de prueba se eliminaron y `counters/clients` volvió a 0.

Pendiente (opcional):

- Registrar App Check y compilar con `RECAPTCHA_SITE_KEY`.
- Recuperación de contraseña para clientes (hoy es asistida por el negocio).
- Exportación de clientes/historial y notificaciones externas.
- Pruebas de reglas con el emulador.

## Desviaciones respecto al plan original

1. `html5_qrcode` no existe en pub.dev; se usa `mobile_scanner` con soporte web.
2. Sin Cloud Functions ni Storage (requieren Blaze): las operaciones se ejecutan en transacciones del cliente y las reglas imponen las restricciones.
3. Se añadieron `pending_requests`, `rate_limits`, `counters/clients` y `usernames` para aplicar anti-duplicado, rate limit, límite y unicidad sin servidor.
4. Se añadió `rejectStampRequest` y la colección `redemptions`.
5. El límite de usuarios cuenta solo clientes (`role: "client"`).
6. `config` es de lectura pública para el branding previo al login.
7. El logo se guarda en base64 dentro de `config/main.logoUrl`, con reducción a 512 px y tope de 600 KB.
8. Firestore usa la base con nombre `default` (no `(default)`) porque crear `(default)` por API exige plan Blaze.
9. El escáner QR requiere HTTPS o localhost; la entrada manual es el fallback.
10. `functions/` se conserva como referencia opcional del backend original, pero no se despliega ni es necesario.
11. El rol de plataforma vive en `admins/{uid}.role = "superadmin"` en lugar de claims, para poder cambiarlo desde la consola sin redeploy ni re-login forzado.
12. La prueba pasó de Remote Config a Firestore (`config/main.trialExpiryAt`) para que el superadministrador pueda renovarla en caliente; Remote Config queda como respaldo.
13. El alta de administradores adicionales se hace sin Cloud Functions: app secundaria de Auth para crear la cuenta + escritura privilegiada de `admins/{uid}` con rollback. Las reglas impiden la escalada de roles.
