# Sistema CMMS Grupo Macsa

Sistema de Gestión de Mantenimiento de Activos para la empresa camaronera **Grupo Macsa**, construido con **Flutter** usando **Clean Architecture + MVVM** y **Firebase Firestore** como backend.

**Proyecto Firebase:** `practica-macsa`

## Arquitectura

```
lib/
├── app/          # Config, DI (GetIt), Router, Pantalla Raíz (login/home)
├── core/         # Errores, Use Cases base, utilidades
└── features/     # Módulos (Vertical Slicing)
    ├── assets/           # Equipos y activos (completo)
    ├── work_orders/      # Órdenes de trabajo (esqueleto)
    ├── kardex/           # Kardex inmutable (esqueleto)
    └── auth_permissions/ # Login, usuarios y permisos RBAC
```

Cada módulo se divide en tres capas:

- **Domain** (Dart puro): Entidades, contratos de repositorios y Use Cases. Sin dependencias de Flutter ni Firebase.
- **Data**: Modelos DTO (`fromFirestore`/`toFirestore`), DataSources (remoto + caché local) e implementaciones de repositorios. Estrategia **cache-first** (lee `Source.cache` antes que `Source.server`).
- **Presentation (MVVM)**: ViewModels (`ChangeNotifier`) que consumen únicamente Use Cases, y Views reactivas con `Provider`.

### Flujo de autenticación

El sistema usa una **tabla de usuarios** en Firestore (`/users`) en lugar de Firebase Auth. Las contraseñas **nunca** se almacenan en texto plano: se guardan con **PBKDF2-HMAC-SHA256** (salt aleatorio de 16 bytes, iteraciones por usuario vía `passwordIterations`; el valor actual es 20.000 porque la verificación corre en el cliente con Dart puro; ver `lib/core/security/password_hasher.dart`). Incluye **bloqueo temporal de cuenta** (5 intentos fallidos → bloqueo de 5 minutos) implementado con transacciones sobre el contador `failedLoginAttempts`/`lockedUntil`.

**Esquema del documento `/users/{userId}`:**

| Campo                 | Tipo       | Ejemplo                        |
|-----------------------|-----------|--------------------------------|
| `username`            | `string`  | `admin`                        |
| `displayName`         | `string`  | `Administrador General`        |
| `passwordSalt`        | `string`  | base64 16 bytes (PBKDF2 salt)  |
| `passwordHash`        | `string`  | base64 32 bytes (PBKDF2 hash)  |
| `passwordIterations`  | `int`     | `20000`                       |
| `permissions`         | `array`   | `["asset.create","asset.edit",…]` |

> ⚠️ **Nunca** debe existir el campo `password` en `firestore.rules` se prohíbe explícitamente.

### Modelo de seguridad (reglas Firestore)

Sin Firebase Auth no existe identidad verificable en el servidor, por lo que la **autorización por permiso (RBAC) se aplica en la interfaz** (`AuthViewModel.hasPermission`) y **no es verificable** en `firestore.rules`. Para autorización server-side por permiso hay que migrar a Firebase Authentication. Lo que las reglas SÍ garantizan es la **integridad de los datos**:

- `/kardex_logs` es **append-only** (solo `create`/`read`, jamás `update`/`delete`).
- Ninguna colección permite borrado físico (`delete: if false`); las bajas son lógicas.
- En `/assets` los campos de jerarquía (`areaId`, `parentAssetId`, `level`, `ancestors`) son **inmutables**; los estados/niveles están restringidos a los enums del dominio y `imageData` < 1,1 MiB.
- En `/users` está prohibido escribir el campo `password`; el `username` es inmutable.
- `/deletion_request_states/{assetId}` es un **candado transaccional** leído dentro de cada transacción (alta, aprobación, rechazo, edición, transferencia y reactivación) que elimina carreras: solicitudes duplicadas, dobles resoluciones y operaciones sobre activos con baja pendiente.
- `/deletion_requests` tiene `assetId` inmutable y estado restringido a `pending/approved/rejected`.

### Reglas de negocio implementadas

- **Transferencia de activos** (`TransferAssetUseCase`): solo se transfieren equipos en estado `ACTIVE` y **a un área distinta** de la de origen. Usa una transacción atómica que (1) valida el candado `deletion_request_states`, (2) desactiva el origen, (3) crea el destino con su nuevo ID relacional y (4) registra el evento en `/kardex_logs` de forma inmutable.
- **Reactivación de activos** (`ReactivateAssetUseCase`): solo reactiva activos `TRANSFERRED_DEACTIVATED` (validado dentro de la transacción), restaurando su subárbol completo.
- **Baja de activos con aprobación** (`asset_deletion`): el jefe de área solicita la baja de un activo con motivo (`asset.delete.request`); el gerente de operaciones la aprueba o rechaza (`asset.delete.approve`) desde la bandeja "Solicitudes". Al aprobarse, el activo y **todo su subárbol** pasan a estado `DELETED` (baja lógica, no se borran documentos) y se excluyen de listas, búsquedas, transferencia y reactivación. Cada paso queda registrado en el kardex (`ASSET_DELETE_REQUESTED`, `ASSET_DELETED`, `ASSET_DELETE_REJECTED`).
- **Validaciones de integridad**: no se crean hijos bajo un padre que no esté `ACTIVE` ni bajo activos con baja pendiente; no se solicita la baja de un hijo si un ancestro ya tiene una solicitud pendiente; no se editan activos `DELETED` ni con baja pendiente.
- **Kardex append-only**: la colección `kardex_logs` es inmutable (ver `firestore.rules`); toda alta, edición, transferencia, reactivación y baja registra `ASSET_CREATED`, `ASSET_UPDATED`, `ASSET_TRANSFER`, `ASSET_REACTIVATE`, etc.
- **RBAC dinámico**: `AppUser.hasPermission('asset.transfer')` evalúa si el usuario logueado tiene el permiso para habilitar acciones en las Views. Permisos vigentes: `asset.create`, `asset.edit`, `asset.transfer`, `asset.delete.request`, `asset.delete.approve`.

## Módulo de activos: áreas e IDs jerárquicos

### Áreas (`/areas`)

Cada equipo pertenece a un área. Las áreas viven en la colección `areas` con ID auto-generado secuencial (`A1`, `A2`, `A3`...).

**Esquema del documento `/areas/{areaId}`:**

| Campo          | Tipo     | Ejemplo |
|----------------|----------|---------|
| `id`           | `string` | `A3`    |
| `name`         | `string` | `Planta de Procesamiento` |
| `costCenter`   | `string` | `CC-03` |
| `assetCounter` | `int`    | `3`     |

El ID de la siguiente área se asigna con el contador global en `/counters/areas` (`nextNumber`), dentro de una transacción para evitar colisiones.

### IDs jerárquicos de activos

Los activos se generan con IDs relacionales en lugar de UUID, dentro de una **transacción** que incrementa un contador:

| Nivel        | Formato           | Contador guardado en      |
|--------------|-------------------|---------------------------|
| Equipo       | `A3-002`          | `areas/{id}.assetCounter` |
| Sub-equipo   | `A3-002-01`       | `assets/{id}.childCounter` |
| Parte        | `A3-002-01-01`    | `assets/{id}.childCounter` |
| Sub-parte    | `A3-002-01-01-01` | `assets/{id}.childCounter` |

Los ancestros se almacenan como lista materializada en `ancestors` (ruta completa hasta el padre), y el nivel se deriva de la jerarquía al crear un hijo.

### Navegación

- `AreaSelectionView` → lista de áreas desde Firestore (con FAB para crear área).
- Tap en un área → equipos raíz del área (`parentAssetId == null`).
- Tap en un activo → sus hijos (drill-down); icono de lápiz → editar; FAB → crear hijo del nivel siguiente.

### Imagen del activo (opcional)

Cada activo puede tener una foto. Se guarda en el campo `imageData` del documento como data-URL (`data:image/jpeg;base64,...`), por lo que no requiere servicios extra (solo Firestore).

- Al crear/editar se puede seleccionar desde la galería ("Seleccionar imagen").
- La imagen se redimensiona a máx. 1024 px y se comprime a JPEG (calidad 75) para caber en el límite de 1 MiB por documento.
- Se muestra como miniatura en la tarjeta del activo (sustituye el icono por defecto).
- Si en el futuro se necesitan fotos grandes o varias por activo, migrar a Firebase Cloud Storage solo cambia el origen de la cadena (URL de descarga en lugar de base64).

## Firebase

El proyecto ya está conectado a Firestore (`practica-macsa`). Si necesitas reconectar:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=practica-macsa --platforms=android,web
firebase deploy --only firestore:rules,indexes
```

### Sembrar datos de prueba (usuario, áreas, activos)

El script `scripts/seed_firestore.ps1` crea vía REST (API key web de `lib/firebase_options.dart`) todo lo que la app necesita: usuarios `admin`/`1234`, `jefe`/`1234` (permisos `asset.create`, `asset.edit`, `asset.transfer`, `asset.delete.request`) y `gerente`/`1234` (permisos `asset.create`, `asset.edit`, `asset.transfer`, `asset.delete.approve`), con contraseñas hasheadas con PBKDF2 (vía `dart run tool/hash_password.dart`, la misma implementación que usa la app). También crea el contador `counters/areas`, las áreas `A1`–`A3` y una jerarquía de activos de ejemplo en `assets/` (4 niveles: bomba → motor → rodamiento → rótula).

```powershell
powershell -ExecutionPolicy Bypass -File scripts\seed_firestore.ps1
```

Requisitos previos: el proyecto Firestore `practica-macsa` debe existir y las reglas/índices deben estar desplegados:

```bash
firebase deploy --only firestore:rules,indexes
```

El script es idempotente por documento (usa `PATCH`, que crea o actualiza). Las áreas nuevas también se pueden crear desde la propia app con el FAB "Crear área".

## Ejecutar

```bash
flutter pub get
flutter run -d chrome  # Web
flutter run            # Android / Emulador
flutter build apk      # APK Android
flutter build web      # Build estático web
```

## Pruebas

```bash
flutter test
flutter analyze
```

Pruebas implementadas (49):

- `password_hasher_test.dart` — PBKDF2: salt aleatorio, determinismo, verificación correcta/incorrecta y formato.
- `app_user_model_test.dart` — serialización del usuario sin credenciales y evaluación de permisos; `toFirestore` nunca incluye `password`/hash.
- `transfer_asset_usecase_test.dart` — regla de negocio: rechaza activos no activos.
- `reactivate_asset_usecase_test.dart` — regla de negocio: solo reactiva activos transferidos/deshabilitados.
- `asset_detail_viewmodel_test.dart` — ViewModel del detalle: carga de hijos y reactivación (loading/success/error).
- `request_asset_deletion_usecase_test.dart` — solicitud de baja: motivo obligatorio, activo ya eliminado o con pendiente → rechazo; delega en el repositorio.
- `approve_asset_deletion_usecase_test.dart` — aprobación de baja: rechaza solicitudes ya resueltas; delega.
- `reject_asset_deletion_usecase_test.dart` — rechazo de baja: solicitud no pendiente o sin motivo → rechazo; delega.
- `get_pending_deletion_requests_usecase_test.dart` — lista de solicitudes pendientes.
- `asset_model_test.dart` — serialización ida y vuelta con Firestore, generación de `searchTerms` y `tokenize`.
- `area_model_test.dart` — serialización del área y valores por defecto.
- `asset_list_viewmodel_test.dart` — ViewModel MVVM: estados loading/success/error.
- `app_user_model_test.dart` — serialización del usuario y evaluación de permisos.
- `login_test.dart` — LoginUseCase delega en el repositorio, devuelve null en credenciales inválidas.
- `widget_test.dart` — smoke test de la selección de áreas.
