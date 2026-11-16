# Tarjet Fidel

Aplicación web de tarjetas de fidelidad digitales construida con **Flutter Web** y **Firebase**. Cada negocio tiene su propio proyecto Firebase, pero comparte el mismo código fuente: lo único que cambia por negocio son las credenciales locales de `firebase.web.json` (ignorado por git), el proyecto de `.firebaserc` y la configuración de `config/main`.

Funciona **solo con el plan gratuito Spark**: no usa Cloud Functions, Storage ni ninguna API que exija facturación.

## Demo

Hay una instancia de referencia en **https://tarjet-fidel-app.web.app** (demo del autor; puede dejar de estar disponible). Es solo una demostración: no contiene datos de clientes reales ni credenciales del repositorio.

| Recurso | Estado en la demo |
| --- | --- |
| Hosting | ✅ activo |
| Authentication (correo/contraseña) | ✅ activo |
| Firestore + reglas + índices | ✅ base `default` (ver nota) |
| Remote Config (`trial_expiry_date`) | ✅ publicado (respaldo) |
| Cuenta de administrador | ✅ creada (`admins/{uid}`) |
| Cuenta de superadministrador | ✅ creada (`admins/{uid}` con `role: "superadmin"`) |
| Cloud Functions | ➖ no se usan (requieren Blaze) |
| Storage (logo) | ➖ no se usa (requiere Blaze); el logo va en base64 |
| App Check | ➖ opcional, sin registrar |

> **Nota sobre la base de datos.** Firestore crea por defecto la base `(default)`, pero crearla por API exige facturación. Para funcionar en el plan Spark el proyecto usa una base con **nombre** `default` (sin paréntesis). Ese identificador está en dos sitios y debe coincidir siempre: `AppConfig.firestoreDatabaseId` y `firestore.database` de `firebase.json`. Si algún día se migra a `(default)`, cambia los dos.

## Roles

- **Superadministrador**: dueño de la plataforma (normalmente el programador). Se identifica con `admins/{uid}.role = "superadmin"`. Usa todas las funciones del administrador del negocio y, además, ve la pestaña **Plataforma**, donde consulta la fecha exacta de vencimiento de la prueba y la renueva o la quita. Puede entrar al panel aunque la prueba esté vencida, porque desde ahí la reactiva.
- **Administrador**: dueño o encargado del negocio. Inicia sesión con correo y contraseña reales. Ve solicitudes pendientes en tiempo real, aprueba o rechaza visitas, ajusta la cantidad de sellos, gestiona clientes, canjea premios, edita la configuración del negocio y muestra el QR de check-in. No puede cambiar la fecha de la prueba.
- **Cliente**: se registra con un nombre de usuario único y una contraseña de exactamente 6 dígitos. Internamente se usa el correo sintético `cliente_<usuario>@tarjetfidel.local`. Ve su tarjeta animada, escanea el QR del negocio (o introduce el código manualmente) y consulta su historial.

Un documento `admins/{uid}` sin campo `role` se sigue tratando como administrador del negocio, para no romper instalaciones anteriores.

## Seguridad anti-fraude

Sin Cloud Functions, la lógica de negocio vive en transacciones de Firestore ejecutadas por la app y **las reglas de Firestore son la autoridad final**. Aunque alguien manipule el código del navegador, las reglas impiden el fraude:

- El QR **nunca** otorga sellos: solo crea una solicitud en estado `pending`.
- El cliente no puede aprobar, rechazar ni modificar solicitudes; solo el administrador (`admins/{uid}`) puede pasar una solicitud de `pending` a `approved` o `rejected`.
- El cliente no puede escribir `visits`, `redemptions`, `currentStamps`, `totalVisits`, `role` ni la configuración.
- El código escaneado debe coincidir exactamente con `config/main.checkinCode`.
- **Una sola solicitud pendiente** por cliente (`pending_requests/{uid}`), creada en la misma transacción.
- Límite de **10 solicitudes por cliente cada 24 horas** (`rate_limits/{uid}`), también verificado por las reglas.
- Límite de clientes configurable con `config/main.maxUsers` (por defecto 50), controlado con `counters/clients`.
- Prueba controlada desde Firestore (`config/main.trialExpiryAt`) y reforzada por las reglas; Remote Config (`trial_expiry_date`) solo actúa como respaldo cuando Firestore no tiene fecha.
- Solo el superadministrador puede escribir los campos `trialExpiryAt`, `trialExpiryDate`, `trialUpdatedAt` y `trialUpdatedBy`; el guardado normal de configuración del negocio no los toca.
- Los clientes solo pueden crear su perfil con el correo sintético que corresponde a su nombre de usuario y con los contadores a cero.

## Estructura

```text
tarjet_fidel/
├─ lib/
│  ├─ main.dart                     Arranque, Firebase, App Check y tema dinámico
│  ├─ firebase_options.dart         Credenciales inyectadas por dart-define
│  ├─ app_config.dart               Base de datos, dominio sintético, límites del logo
│  ├─ theme.dart                    Tema y fondo de marca animado
│  ├─ models/                       ConfigModel, UserModel, StampRequestModel, AdminRole
│  ├─ services/
│  │  ├─ auth_service.dart          Registro/login, reset del admin y rollback de Auth
│  │  ├─ backend_service.dart       Transacciones: solicitudes, aprobación, canje, prueba
│  │  ├─ firestore_service.dart     Lecturas en tiempo real y guardado de configuración
│  │  └─ logo_service.dart          Selector de imagen y conversión a base64
│  ├─ screens/                      Acceso, cliente, admin, plataforma y bloqueo de prueba
│  ├─ widgets/                      Tarjeta, QR, escáner, animaciones y confeti
│  └─ utils/                        Códigos, fechas de prueba y metadatos del navegador
├─ tool/configure_firebase.mjs      Asistente de credenciales por negocio
├─ .github/workflows/flutter.yml    CI: analyze + test + build web
├─ firebase.web.example.json        Plantilla sin credenciales
├─ .firebaserc.example              Plantilla de proyecto para la CLI
├─ functions/                       Backend opcional heredado (requiere Blaze, no se despliega)
├─ firestore.rules
├─ firestore.indexes.json
├─ firebase.json
├─ test/
└─ plan.md
```

## Requisitos

- Flutter 3.41+ / Dart 3.11+
- Firebase CLI 15+
- Un proyecto Firebase en el **plan gratuito Spark**
- Opcional: Node.js 22 y Google Cloud CLI, solo para el script de administrador heredado

---

## Puesta en marcha

> **El repositorio no crea proyectos de Firebase.** Crear el proyecto, activar los servicios y registrar la app web es un paso manual en la consola (gratis en Spark). El código solo se conecta al proyecto cuyas credenciales recibe al compilar.

### 1. Crear el proyecto Firebase

Crea un proyecto en la consola de Firebase y activa:

1. **Authentication** → método **Correo electrónico/contraseña**.
2. **Firestore Database** → modo producción, región cercana. La base con nombre `default` la crea `firebase deploy` a partir de `firestore.location` de `firebase.json`; no hace falta crearla a mano.
3. **Remote Config** (opcional, solo como respaldo de la prueba).
4. **Hosting**.

No actives Functions ni Storage: no son necesarios y exigen el plan Blaze.

### 2. Vincular el repositorio con el proyecto

Desde la carpeta `tarjet_fidel`:

```bash
firebase use --add
```

Selecciona el proyecto y usa el alias `default`. Esto actualiza `.firebaserc`. También puedes editarlo a mano:

```json
{
  "projects": {
    "default": "tu-proyecto-firebase"
  }
}
```

> La CLI guarda el proyecto activo por carpeta y a veces ignora `.firebaserc`. Si el despliegue apunta a otro proyecto, añade `--project tu-proyecto-firebase` a cada comando.

### 3. Configurar las credenciales del negocio

```bash
flutter pub get
node tool/configure_firebase.mjs
```

El asistente pide el ID del proyecto, la API key, el App ID y el sender ID de la app web (Firebase Console → **Configuración del proyecto → Tus apps → App web**). Escribe `firebase.web.json` y `.firebaserc`, y ajusta `firestore.database` en `firebase.json`. Esos dos primeros archivos están en `.gitignore`: **no se suben a GitHub**.

También puedes copiar `firebase.web.example.json` a `firebase.web.json` y rellenar los valores a mano.

Compila y ejecuta siempre con el archivo de credenciales:

```bash
flutter run -d chrome --dart-define-from-file=firebase.web.json
flutter build web --release --no-wasm-dry-run --dart-define-from-file=firebase.web.json
```

Si `firebase.web.json` no existe o conserva `REPLACE_ME`, la app muestra una pantalla de configuración en lugar de fallar. `lib/firebase_options.dart` ya no contiene credenciales: solo lee las variables inyectadas al compilar.

### 4. Configurar la prueba

La fuente de verdad es **Firestore**: `config/main.trialExpiryAt` (Timestamp) y su espejo legible `config/main.trialExpiryDate` (ISO 8601). El superadministrador los edita desde la pestaña **Plataforma** del panel; las reglas aplican el bloqueo al instante, sin recompilar ni volver a desplegar.

Remote Config es solo un **respaldo** para instalaciones nuevas que aún no tienen fecha en Firestore. Si quieres usarlo, en **Remote Config → Crear configuración** añade:

| Parámetro | Tipo | Valor de ejemplo |
| --- | --- | --- |
| `trial_expiry_date` | String | `2026-12-31T23:59:59Z` |

Publica los cambios. La app prioriza Firestore y solo consulta Remote Config cuando `config/main` no tiene `trialExpiryAt` ni `trialExpiryDate`. Si no hay ninguna fecha válida, la prueba se considera activa para no bloquear el negocio por error.

La cuenta de superadministrador puede fijar la fecha exacta, sumar +7/+15/+30/+90 días o quitar el límite. Los clientes y el panel del negocio se desbloquean en tiempo real al renovarla.

### 5. Crear el primer administrador

El rol se determina **solo** por el documento `admins/{uid}`; no hacen falta claims personalizados.

1. En **Authentication → Users → Add user**, crea la cuenta con el correo y la contraseña del administrador.
2. Copia su **UID**.
3. En **Firestore → admins**, crea un documento con ese UID y estos campos:

   | Campo | Tipo | Valor |
   | --- | --- | --- |
   | `email` | string | correo del administrador |
   | `displayName` | string | nombre visible |
   | `role` | string | `admin` (opcional; sin `role` también es admin) |
   | `createdAt` | timestamp | ahora |
   | `updatedAt` | timestamp | ahora |

4. En **Firestore → config**, crea el documento `main` con los campos de la sección [Modelo de datos](#configmain). Como mínimo: `businessName`, `stampsGoal`, `checkinCode`, `maxUsers`, `themeColor`.
5. Crea `counters/clients` con `count: 0` (número entero).

Con eso el administrador ya puede entrar y el panel permite terminar de configurar el negocio.

#### Crear el superadministrador

Repite los pasos con la cuenta del programador, pero guarda `role: "superadmin"` en `admins/{uid}`. Esa cuenta verá la pestaña **Plataforma** y podrá renovar la prueba incluso si ya venció. El documento de `admins` no se puede escribir desde la app: créalo desde la consola o con el script heredado.

> Alternativa heredada: `functions/scripts/create-admin.mjs` crea la cuenta, el documento `admins`, los claims y siembra `config/main` usando credenciales locales de Google Cloud. Acepta `--role superadmin`. Funciona sin facturación, pero no es necesario.

### 6. Desplegar reglas e índices

```bash
firebase deploy --only firestore:rules,firestore:indexes --project tu-proyecto-firebase
```

La primera vez, los índices compuestos tardan unos minutos en construirse. Si el panel muestra un error de índice, espera y vuelve a intentarlo.

### 7. Compilar y desplegar la web

```bash
flutter build web --release --no-wasm-dry-run --dart-define-from-file=firebase.web.json
firebase deploy --only hosting --project tu-proyecto-firebase
```

Para probar en local:

```bash
flutter run -d chrome --dart-define-from-file=firebase.web.json
```

La cámara solo funciona en **HTTPS** o en `localhost`. Si el navegador no la permite, el escáner ofrece la entrada manual del código.

### 8. Activar App Check (opcional)

App Check no es obligatorio y **no está registrado**. Si quieres añadirlo:

1. En Firebase Console → **App Check**, registra la app web con **reCAPTCHA v3**.
2. Compila con la clave inyectada:

   ```bash
   flutter build web --release \
     --dart-define-from-file=firebase.web.json \
     --dart-define=RECAPTCHA_SITE_KEY=TU_SITE_KEY
   firebase deploy --only hosting
   ```

3. Activa la aplicación obligatoria de App Check para **Firestore** en la consola.

La app activa App Check solo si se compiló con `RECAPTCHA_SITE_KEY`; sin esa variable sigue funcionando, pero sin la protección adicional.

---

## Uso

### Administrador

1. Inicia sesión con su correo y contraseña.
2. Pestaña **QR**: genera o copia el código de check-in y muestra el QR en el mostrador.
3. Pestaña **Solicitudes**: aparecen en tiempo real. Aprueba con la cantidad de sellos editable o rechaza.
4. Pestaña **Clientes**: busca clientes, consulta su progreso y canjea premios (reinicia sellos y deja registro en `redemptions`).
5. Pestaña **Configuración**: nombre, logo, meta de sellos, premio, color, límite de usuarios y contacto. La fecha de la prueba solo se muestra; no se edita aquí.

### Superadministrador

1. Inicia sesión con su cuenta; entra al panel aunque la prueba esté vencida.
2. Pestaña **Plataforma**: muestra si la prueba está activa o vencida, los días restantes, la fecha local y el valor UTC exacto.
3. Fija una fecha y hora con el selector, o usa los botones **+7 / +15 / +30 / +90 días**.
4. **Guardar fecha** aplica el cambio al instante; **Sin límite** elimina el vencimiento.
5. La barra superior muestra un chip con el tiempo restante que lleva directo a la pestaña.

Además puede usar todas las pestañas del administrador del negocio.

### Cliente

1. Se registra con usuario y contraseña de 6 dígitos.
2. Escanea el QR del negocio o introduce el código manualmente.
3. Se crea una solicitud pendiente; el mensaje confirma que debe esperar la aprobación.
4. Cuando el administrador aprueba, los sellos aparecen animados en tiempo real.
5. Al completar la meta, la tarjeta muestra el premio listo.

### Recuperar la contraseña del administrador

En la pestaña de administrador, el enlace **¿Olvidaste tu contraseña?** envía un correo de restablecimiento de Firebase Auth. Los clientes usan un correo sintético y no pueden recibir correos: si olvidan su contraseña de 6 dígitos, el negocio debe recrear la cuenta o asistirlos manualmente.

---

## Animaciones

La interfaz usa `flutter_animate` y un pequeño kit propio en `lib/widgets/`:

| Widget | Dónde se usa | Efecto |
| --- | --- | --- |
| `Reveal` | Login, paneles, tarjetas y banners | Fundido con deslizamiento suave al montar |
| `StaggeredReveal` | Listas de solicitudes, clientes y visitas | Cada fila entra un poco después que la anterior |
| `HoverLift` | Tarjetas y filas | Se elevan y escalan al pasar el ratón |
| `Pulse` | Logo, insignias y avisos | Pulso continuo y discreto |
| `ShimmerHighlight` | Código de check-in y logo | Brillo que recorre el contenido |
| `AnimatedIndexedStack` | Panel del administrador | Fundido al cambiar de pestaña sin perder estado |
| `ConfettiBurst` | Aprobar solicitud y canjear premio | Confeti de una sola vez |
| `CelebrationOnChange` | Tarjeta del cliente | Confeti cuando suben los sellos |
| `BrandBackground` | Login, splash y bloqueo | Degradado y luces en movimiento lento |

Todas respetan el ciclo de vida de Flutter, se desechan en `dispose()` y no bloquean toques. El tema y el título del navegador también se actualizan con `config/main` (`ConfigMetaSync`).

---

## Modelo de datos

### `config/main`

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `businessName` | string | Nombre del negocio |
| `logoUrl` | string | URL `https://…` o `data:image/…;base64,…` |
| `stampsGoal` | number | Sellos para el premio |
| `rewardDescription` | string | Texto del premio |
| `themeColor` | string | Color `#RRGGBB` |
| `maxUsers` | number | Límite de clientes |
| `checkinCode` | string | Código dentro del QR |
| `contactInfo` | string | Contacto al expirar la prueba |
| `trialExpiryDate` | string \| null | Fecha de prueba en ISO 8601 (espejo legible) |
| `trialExpiryAt` | timestamp | Fecha de prueba que aplican las reglas |
| `trialUpdatedAt` | timestamp | Última modificación de la prueba |
| `trialUpdatedBy` | string | UID del superadministrador que la modificó |

El logo se guarda como `data:image/...;base64,...` dentro de `logoUrl` (o como URL externa). El selector acepta archivos de hasta 8 MB, reduce la imagen a 512 px de ancho y rechaza el resultado si supera 600 KB, para no acercarse al límite de 1 MiB por documento de Firestore.

### `users/{uid}`

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `username` | string | Usuario normalizado |
| `usernameLower` | string | Copia en minúsculas para unicidad |
| `internalEmail` | string | `cliente_<usuario>@tarjetfidel.local` |
| `displayName` | string | Nombre visible |
| `currentStamps` | number | Sellos actuales |
| `totalVisits` | number | Visitas aprobadas |
| `role` | string | `client` |
| `isRewardReady` | boolean | Meta alcanzada |
| `createdAt` / `updatedAt` | timestamp | Auditoría |

### `stamp_requests/{id}`

`userId`, `userName`, `status` (`pending` / `approved` / `rejected`), `stampsAwarded`, `code`, `createdAt`, `approvedAt`, `approvedBy`, `rejectedAt`, `rejectedBy`, `updatedAt`.

### `visits/{id}`

`userId`, `stamps`, `approvedBy`, `requestId`, `timestamp`. Historial inmutable.

### `redemptions/{id}`

`userId`, `userName`, `stampsBefore`, `rewardDescription`, `redeemedBy`, `timestamp`.

### `pending_requests/{uid}`

`userId`, `requestId`, `createdAt`. Una sola solicitud pendiente por cliente.

### `rate_limits/{uid}`

`count`, `windowStart`, `updatedAt`. Ventana móvil de 24 horas con máximo 10 solicitudes.

### `counters/clients`

`count`, `updatedAt`. Número de clientes registrados, comparado con `config/main.maxUsers`.

### `usernames/{username}`

`uid`, `username`, `createdAt`. Reserva el nombre de usuario de forma atómica.

### `admins/{uid}`

`email`, `displayName`, `role`, `createdAt`, `updatedAt`. Determina el rol: `superadmin` para el dueño de la plataforma; cualquier otro valor (o la ausencia de `role`) es administrador del negocio.

---

## Reglas y permisos

- `config`: lectura pública (branding en el login). El administrador puede crear la configuración inicial y actualizar los campos del negocio, pero no `trial*`; borrar o cambiar la fecha de prueba queda reservado al superadministrador.
- `users`: el cliente lee su perfil; el admin lee todos. El cliente solo puede crear su propio perfil (una vez, como `client`, con contadores a cero y correo sintético coherente) y cambiar `displayName`/`updatedAt`. El admin puede cambiar cualquier campo. Nadie borra perfiles.
- `usernames`: se crea en la misma transacción que el perfil y nunca se modifica ni se borra.
- `counters/clients`: solo se incrementa de uno en uno al crear un cliente y no puede superar `maxUsers`.
- `stamp_requests`: el cliente lee las suyas; el admin lee todas. El cliente solo crea solicitudes `pending` con el código vigente y una solicitud pendiente asociada. Solo el admin las aprueba o rechaza, con 1–10 sellos.
- `pending_requests`: el cliente crea la suya junto con la solicitud y el admin la borra al resolverla.
- `rate_limits`: el cliente solo incrementa su contador (máximo 10) o lo reinicia al pasar 24 horas.
- `visits`: lectura del propio cliente o del admin; escritura solo admin.
- `redemptions`: lectura solo admin; escritura solo admin.
- `admins`: cada usuario solo puede comprobar su propio documento; listar y escribir está prohibido.

> La lectura pública de `config` expone también `checkinCode`. El código no es un secreto criptográfico: el QR se muestra públicamente en el mostrador y el sello siempre requiere aprobación humana. El riesgo se limita a solicitudes de spam, que están limitadas por autenticación, rate limit y anti-duplicado.

---

## Replicar para otro negocio

Cada negocio debe tener un **proyecto Firebase independiente** para aislar datos y usuarios. Todo el proceso cabe en el plan gratuito.

> **Importante:** este repositorio es una plantilla, no un generador de proyectos. Cambiar el nombre del negocio, el logo o los colores en `config/main` **no crea** un proyecto Firebase nuevo: solo cambia la marca de la instancia actual. Para otra empresa hay que crear un proyecto aparte y seguir estos pasos. Así los datos quedan aislados de verdad.

| Qué cambias | Dónde | Efecto |
| --- | --- | --- |
| Nombre, logo, premio, meta, color | `config/main` (panel de administración) | Solo cambia la marca; sigue usando el mismo proyecto y los mismos datos |
| Credenciales del proyecto | `firebase.web.json` (ignorado por git) | La app se conecta a otro Firebase |
| Proyecto destino de la CLI | `.firebaserc` | A qué proyecto se despliegan reglas, índices y hosting |
| Base de Firestore | `firestore.database` en `firebase.json` + `FIRESTORE_DATABASE_ID` en `firebase.web.json` | Otra base dentro del proyecto |
| Dominio del correo sintético | `AppConfig.clientEmailDomain` **y** `firestore.rules` | Cambia el correo interno de los clientes; los dos valores deben coincidir |

1. Crea el nuevo proyecto Firebase (plan Spark) y una app web dentro de él.
2. Activa Auth (correo/contraseña), Firestore, Remote Config y Hosting.
3. Configura las credenciales y el proyecto de la CLI:

   ```bash
   node tool/configure_firebase.mjs
   ```

   El asistente escribe `firebase.web.json`, crea `.firebaserc` y ajusta `firestore.database` en `firebase.json`. También puedes copiar `firebase.web.example.json` a `firebase.web.json` y rellenarlo a mano.

4. Opcional: publica `trial_expiry_date` en Remote Config (por ejemplo `2026-12-31T23:59:59Z`) como respaldo. La fecha efectiva se fija en Firestore desde la pestaña **Plataforma** del superadministrador.
5. Despliega reglas e índices:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project nuevo-proyecto
   ```

6. Crea el administrador (usuario de Auth + documento `admins/{uid}`) y, si corresponde, el superadministrador con `role: "superadmin"`; luego `config/main` y `counters/clients` como se explica en el paso 5 de la puesta en marcha.
7. Compila y despliega la web con las credenciales del negocio:

   ```bash
   flutter build web --release --no-wasm-dry-run \
     --dart-define-from-file=firebase.web.json
   firebase deploy --only hosting --project nuevo-proyecto
   ```

8. Prueba el flujo completo: registro de cliente, escaneo, aprobación, canje y bloqueo por prueba.

> `firebase.web.json` y `.firebaserc` están en `.gitignore`: cada negocio guarda los suyos y nunca se suben al repositorio. El CI compila con `firebase.web.example.json`, así que no necesita secretos.

No compartas un mismo proyecto Firebase entre negocios: las reglas y los datos están pensados para aislamiento total. Si el nuevo proyecto usa otra base de Firestore, cámbiala también en `firestore.database` de `firebase.json` y en `FIRESTORE_DATABASE_ID` de `firebase.web.json` (el asistente lo hace por ti).

### Qué no debe subirse al repositorio

- `firebase.web.json` y `.firebaserc` (credenciales y proyecto de cada negocio).
- Contraseñas, correos de administradores reales, códigos de check-in y archivos de service account.
- `build/`, `.dart_tool/`, `.firebase/` y `functions/node_modules/`.

La **API key web de Firebase no es un secreto** (viaja en el navegador), pero conviene restringirla en Google Cloud Console → **APIs y servicios → Credenciales** para que solo funcione desde tus dominios. Si publicas una demo, usa un proyecto distinto al de producción y no publiques el correo del administrador.

---

## Desarrollo

```bash
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run \
  --dart-define-from-file=firebase.web.json
```

El flujo de GitHub Actions (`.github/workflows/flutter.yml`) ejecuta `analyze`, `test` y el build web en cada push o pull request, usando `firebase.web.example.json`. No requiere secretos porque la app, sin credenciales reales, solo muestra la pantalla de configuración.

Para usar los emuladores:

```bash
firebase emulators:start
```

La app no está conectada a los emuladores por defecto. Si quieres usarlos, añade en `lib/main.dart` las llamadas `useFirestoreEmulator` y `useAuthEmulator` antes de `runApp`, y usa `--dart-define` para no incluirlas en producción.

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| Aparece “Configura Firebase para empezar” | Falta `firebase.web.json` o conserva `REPLACE_ME` | Ejecuta `node tool/configure_firebase.mjs` y compila con `--dart-define-from-file=firebase.web.json` |
| `permission-denied` al leer `admins` o `config` | Reglas no desplegadas o falta `admins/{uid}` | Despliega reglas y crea el documento del admin |
| `permission-denied` al registrarse | Falta `counters/clients`, la prueba venció o el correo no coincide con el usuario | Crea `counters/clients` con `count: 0`, revisa `trialExpiryAt` y el nombre de usuario |
| Error de índice compuesto | Los índices aún se están creando | Despliega `firestore:indexes` y espera unos minutos |
| La prueba se bloquea antes de tiempo | `config/main.trialExpiryAt` vencido | Entra con el superadministrador y renuévala en la pestaña **Plataforma** |
| El administrador no ve la pestaña **Plataforma** | `admins/{uid}.role` no es `superadmin` | Corrige el campo en Firestore y vuelve a iniciar sesión |
| “El negocio alcanzó su límite de usuarios” | `config/main.maxUsers` alcanzado | Súbelo desde el panel de administración |
| “Ese nombre de usuario ya está en uso” | Ya existe la cuenta o el perfil | Prueba otro usuario; revisa Auth/Firestore |
| El logo no se guarda | La imagen supera 600 KB tras reducirla | Usa un logo más pequeño o una URL externa |
| La cámara no abre | Contexto no seguro o permiso denegado | Usa HTTPS/localhost y la entrada manual |
| El admin no ve el panel | Falta `admins/{uid}` | Créalo con el UID correcto y vuelve a iniciar sesión |
| `403 This API method requires billing` al desplegar Firestore | Firebase intenta crear `(default)` | Mantén `firestore.database` en `firebase.json` (base con nombre `default`) |
| El despliegue apunta a otro proyecto | La CLI ignora `.firebaserc` | Añade `--project tu-proyecto-firebase` |

---

## Decisiones y desviaciones del plan original

- `html5_qrcode` no existe en pub.dev; se sustituyó por `mobile_scanner` (BarcodeDetector/zxing-wasm en web).
- **Sin Cloud Functions ni Storage**: ambos exigen el plan Blaze. Las seis operaciones de negocio se movieron a transacciones de Firestore en el cliente (`lib/services/backend_service.dart`) y las reglas son la autoridad anti-fraude.
- El registro de clientes se hace en el cliente: `createUserWithEmailAndPassword` y, en una transacción, `users/{uid}`, `usernames/{username}` y el incremento de `counters/clients`. Si la transacción falla, la cuenta de Auth se elimina.
- El logo se guarda en base64 dentro de `config/main.logoUrl`; no hay bucket de Storage.
- Se añadió `pending_requests`, `rate_limits`, `counters/clients` y `usernames` para que las reglas puedan imponer anti-duplicado, rate limit, límite de usuarios y unicidad sin Functions.
- `getAfter()` se usa para comprobar escrituras de la misma transacción (`stamp_requests` ↔ `pending_requests`, `counters` ↔ `users`), porque `exists()`/`get()` no ven los cambios aún no confirmados.
- Se añadió la colección `redemptions` para auditar los canjes de premios.
- El límite de usuarios cuenta solo documentos con `role: "client"`, no administradores.
- `config` es de lectura pública para poder mostrar el branding en el login; el código de check-in no se considera un secreto.
- Firestore usa la base con **nombre** `default` en lugar de `(default)`, porque crear `(default)` por API exige plan Blaze. El identificador se repite en `AppConfig.firestoreDatabaseId` y `firebase.json`.
- `functions/` se conserva como referencia opcional del backend original en TypeScript, pero `firebase.json` ya no lo despliega y la app no depende de él.
- Las credenciales ya no viven en el repositorio: `lib/firebase_options.dart` las lee por `String.fromEnvironment` y `firebase.web.json` (ignorado por git) las inyecta con `--dart-define-from-file`. El CI usa la plantilla.
- El rol de plataforma se guarda en `admins/{uid}.role = "superadmin"` y no en claims: así se puede cambiar desde la consola sin volver a iniciar sesión ni desplegar Functions. Los documentos sin `role` siguen siendo administradores del negocio.
- La prueba pasó de Remote Config a Firestore (`config/main.trialExpiryAt`) para que el superadministrador pueda renovarla en caliente. Las reglas solo permiten tocar los campos `trial*` al superadministrador, y `AuthGate` escucha `config/main` para desbloquear la app en tiempo real.

---

## Pendientes recomendados

Nada de esto es obligatorio para operar, pero mejora la seguridad y la experiencia:

- [ ] Registrar **App Check** con reCAPTCHA v3 y compilar con `--dart-define=RECAPTCHA_SITE_KEY=…`.
- [ ] Añadir **recuperación de contraseña para clientes** (por ejemplo, un código de un solo uso generado por el admin).
- [ ] Exportar clientes e historial a CSV desde el panel.
- [ ] Notificaciones push o por correo cuando se aprueba una solicitud (requiere un servicio externo o Blaze).
- [ ] Multi-negocio en un solo proyecto con `businessId` en cada documento y reglas por pertenencia.
- [ ] Sustituir el correo sintético por autenticación anónima si se quiere evitar el límite de cuentas de Auth.
- [ ] Internacionalización (ES/EN) y modo oscuro.
- [ ] Pruebas de widgets para las pantallas principales y pruebas de reglas con el emulador.
