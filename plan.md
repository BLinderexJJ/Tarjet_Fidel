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
- El rol se determina por la existencia de `admins/{uid}`; no se usan claims.
- No hay registro de administradores en la interfaz.
- El administrador puede pedir un enlace de restablecimiento de contraseña desde el login; los clientes no reciben correo porque usan un correo sintético.

### Cliente

- Se registra con un nombre de usuario único y una contraseña de exactamente 6 dígitos.
- Internamente se usa el correo sintético `cliente_<usuario>@tarjetfidel.local`.
- Validación del usuario: `^[a-zA-Z0-9](?:[a-zA-Z0-9._-]{2,31})$`, nombre visible de hasta 60 caracteres.
- Registro en el cliente: `createUserWithEmailAndPassword` + transacción (`users/{uid}`, `usernames/{username}`, incremento de `counters/clients`). Si falla la transacción, se elimina la cuenta de Auth.

## Modelo de datos

### `config/main`

`businessName`, `logoUrl`, `stampsGoal`, `rewardDescription`, `themeColor`, `maxUsers`, `checkinCode`, `contactInfo`, `trialExpiryDate`, `trialExpiryAt`.

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
- `admins/{uid}`: `email`, `displayName`, `createdAt`, `updatedAt`.

## Operaciones de negocio (transacciones del cliente)

### Registro de cliente

- Verifica la prueba con `config/main.trialExpiryDate` y el límite con `counters/clients`.
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

- Lee `trial_expiry_date` de Remote Config y, si no está disponible, el espejo de `config/main`.
- Si no hay fecha válida, la prueba se considera activa.

## Reglas de seguridad

- `config`: lectura pública, escritura solo admin.
- `users`: el cliente crea una sola vez su perfil con contadores a cero y correo coherente; después solo cambia `displayName`/`updatedAt`. El admin puede cambiar cualquier campo. Nadie borra.
- `usernames`: creación en la misma transacción que el perfil; sin update ni delete.
- `counters/clients`: incrementos de uno en uno, sin superar `maxUsers`, ligados a la creación del perfil mediante `getAfter()`.
- `stamp_requests`: el cliente solo crea solicitudes `pending` con el código vigente y su `pending_requests/{uid}` asociado; solo el admin aprueba/rechaza con 1–10 sellos.
- `pending_requests`: el cliente crea la suya; el admin la borra al resolver.
- `rate_limits`: el cliente solo incrementa hasta 10 o reinicia la ventana al pasar 24 horas.
- `visits` y `redemptions`: escritura solo admin; lectura del propio cliente o del admin (redemptions solo admin).
- `admins`: cada usuario solo comprueba su propio documento.

> `getAfter()` es obligatorio para comprobar escrituras de la misma transacción: `exists()` y `get()` no ven los cambios aún no confirmados.

## Prueba de 15 días

- `trial_expiry_date` en Remote Config (ISO 8601) es la fuente de verdad para la app.
- `config/main.trialExpiryAt` (Timestamp) es el espejo que usan las reglas, porque no pueden convertir cadenas ISO.
- Al expirar, la app muestra la pantalla de bloqueo con los datos de contacto y las reglas rechazan las escrituras de los clientes.
- El administrador puede renovar editando Remote Config y la configuración; no hace falta recompilar.

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
- [x] `checkTrialStatus` (Remote Config + espejo)
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

- [x] Remote Config con `trial_expiry_date`
- [x] Pantalla de bloqueo por expiración
- [x] Hosting desplegado
- [x] Administrador creado
- [x] `flutter analyze`, `flutter test` y `flutter build web` correctos
- [x] Reglas verificadas de extremo a extremo con el SDK cliente
- [x] Documentación de replicación

### Fase 8: Replicación por negocio

- [x] Checklist para crear el proyecto Firebase
- [x] Checklist para activar servicios (sin Functions ni Storage)
- [x] Checklist para Remote Config
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

## Estado de implementación

Verificado y desplegado:

- `flutter analyze` → sin incidencias.
- `flutter test` → 17 pruebas superadas (modelos, códigos, animaciones y accesibilidad).
- `flutter build web --release --no-wasm-dry-run --dart-define-from-file=firebase.web.json` → compilación correcta.
- Proyecto Firebase de referencia creado y app web registrada.
- Credenciales reales en `firebase.web.json` (ignorado por git); `lib/firebase_options.dart` las lee por `dart-define`.
- Authentication (correo/contraseña) activo.
- Firestore (base con nombre `default`) con reglas e índices desplegados.
- Remote Config `trial_expiry_date` publicado (versión 1).
- Administrador de referencia con documento `admins/{uid}`; inicio de sesión verificado.
- `config/main` sembrada; `counters/clients` en 0.
- Hosting de referencia desplegado.

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
