# AGENTS.md

Sistema CMMS de **Grupo Macsa** (gestión de mantenimiento). Flutter + Clean Architecture + MVVM con **Firebase Firestore** como backend (proyecto `practica-macsa`, sin Firebase Auth). Detalle extendido en `README.md`.

## Comandos

```bash
flutter pub get
flutter analyze   # hoy: ~70 warnings/info preexistentes, 0 errores; no introducir nuevos errores/warnings
flutter test      # 128 tests, todos offline con mocks (mocktail); NO requieren Firebase ni red
flutter test test/features/assets/data/models/asset_model_test.dart  # un archivo
flutter test --name "transfer"                                       # por nombre
```

- Ejecutar: `flutter run -d chrome` / `-d windows`. Builds: `flutter build apk|web`.
- Reglas/índices: `firebase deploy --only firestore:rules,indexes`
- Reconectar Firebase: `flutterfire configure --project=practica-macsa --platforms=android,web`
- Sembrar datos: `powershell -ExecutionPolicy Bypass -File scripts\seed_firestore.ps1` (idempotente vía REST; los hashes los genera `dart run tool/hash_password.dart`, misma implementación que la app).

## Arquitectura

- Entrada: `lib/main.dart` → `Firebase.initializeApp` → `configureDependencies()` → `MacsaApp`.
- **La DI es manual**: todo use case/repositorio/ViewModel nuevo DEBE registrarse en `lib/app/di/get_it.dart` o nunca se instanciará.
- Features en `lib/features/<módulo>/{domain,data,presentation}`:
  - `domain`: Dart puro, sin Flutter/Firebase (entidades, contratos, use cases).
  - `data`: modelos (`fromFirestore`/`toFirestore`), datasources remoto+caché local, repos impl. Cache-first SOLO en nativo (`kIsWeb` salta caché; la caché solo se usa si trae resultados).
  - `presentation`: ViewModels `ChangeNotifier` que consumen SOLO use cases; Views con `Provider`.
- Excepción: 3 ViewModels reciben `FirebaseFirestore` directo para listeners `.snapshots()` en tiempo real (`breakdown_alerts`, `my_reports_notifications`, `password_reset_alerts`).
- El ID del documento en `assets` ES el código relacional del activo (`assets/{A3-002}`), no hay campo `id`.

## Mapa Firestore y reglas de integridad

Colecciones: `users`, `areas`, `assets`, `counters` (docs `areas`/`work_orders`/`preventive_schedules`), `kardex_logs`, `deletion_requests`, `deletion_request_states`, `work_orders`, `breakdown_reports`, `preventive_schedules`, `password_reset_requests`.

**`firestore.rules` es la fuente ejecutable de verdad de las restricciones:**
- Ninguna colección permite borrado físico (`delete: if false`): todas las bajas son lógicas.
- `kardex_logs` es append-only (solo create/read); toda mutación escribe su evento ahí en la MISMA transacción (`ASSET_CREATED`, `ASSET_UPDATED`, `ASSET_TRANSFER`, `ASSET_REACTIVATE`, `WORK_ORDER_CREATED`, …).
- `assets`: inmutables `areaId`, `parentAssetId`, `level`, `ancestors` y `serial` (si existe); enums restringidos (status: `active/transferredDeactivated/inactive/deleted`; level: `equipment/subEquipment/part/subPart`); `imageData` < 1.1 MiB (base64).
- `users`: prohibido el campo `password`; `username` inmutable.

**IDs y correlativos se generan DENTRO de transacciones** (contadores, no UUID):
- Áreas: `A{n}` desde `counters/areas.nextNumber`.
- Activos: equipo `{área}-00N` (contador `areas.assetCounter`); hijo `{padre}-NN` (contador `assets.childCounter`); `ancestors` = ruta materializada.
- OTs: `OT-{año}-0001` desde `counters/work_orders`. Preventivos: `PM-{año}-0001` desde `counters/preventive_schedules`.
- Candado transaccional `deletion_request_states/{assetId}`: TODA transacción (alta, edición, traspaso, reactivación, cambio de estado, aprobar/rechazar baja) lo lee primero y aborta si está `pending`.
- Transferencia: duplica el subárbol completo al área destino con nuevos IDs (BFS determinístico) y desactiva el origen (`transferredDeactivated`, `transferredToId` en la raíz) en una sola transacción. Reactivar solo aplica a ese estado.
- Búsqueda: array tokenizado `searchTerms` con `arrayContainsAny` (máx 10 tokens) refinado AND en cliente. Índices compuestos requeridos en `firestore.indexes.json`.
- Serial único global para equipos raíz (validado contra no eliminados).

## Auth y RBAC

- Login propio contra `/users` (NO Firebase Auth). PBKDF2-HMAC-SHA256: salt base64 16 B, hash base64 32 B, iteraciones por usuario (`passwordIterations`, hoy 20000). Implementación única en `lib/core/security/password_hasher.dart`.
- Bloqueo: 5 intentos fallidos → `lockedUntil` (+5 min) vía transacción sobre `failedLoginAttempts`/`lockedUntil`; reset al acertar. El lookup de usuario prueba tal cual → minúsculas → MAYÚSCULAS.
- Campos extra de sesión: `disabled`, `mustChangePassword`, `passwordResetRequested(At)`; el reset también registra en `password_reset_requests`.
- Roles `admin|jefe|reportador|lector` con permisos por defecto en `lib/features/auth_permissions/domain/entities/user_role.dart`. Permisos tipo `modulo.accion` (`asset.create`, `asset.delete.approve`, `user.manage`, …). `admin` pasa todas las verificaciones por rol en `AppUser.hasPermission`.
- La autorización RBAC vive SOLO en la UI (`AuthViewModel.hasPermission`): las rules garantizan integridad, no autorización (no hay identidad de servidor).

## Migración a SQL Server (objetivo activo del repo)

Se está migrando de Firestore a **SQL Server (T-SQL)**. Entregable: script(s) init funcionales y exactos (BD, tablas, relaciones, SPs, índices, seed) cubriendo TODO el flujo: login/bloqueo, desglose de permisos RBAC, áreas, jerarquía de activos (CRUD por niveles), traspaso/reactivación de subárboles, flujo de bajas con aprobación, kardex append-only, OTs, averías, preventivos, dashboard y resets de contraseña.

Derivar el esquema SIEMPRE de estas fuentes (no inventar):
- `firestore.rules` → cada restricción = CHECK/FK/trigger/permiso SQL.
- `lib/features/*/data/models/*.dart` (`fromFirestore`/`toFirestore`) → campos y tipos exactos.
- `data/repositories/` y `data/datasources/` → cada consulta/transacción = un SP (conservar atomicidad).
- `firestore.indexes.json` → índices. `user_role.dart` → catálogo de roles/permisos.

Decisiones de mapeo ya implicadas por el dominio:
- IDs-documento con significado de negocio → PKs naturales (código jerárquico de activo, correlativos OT/PM).
- Docs `counters` → tabla de contadores o SEQUENCE actualizada dentro de la MISMA transacción del SP.
- Candado `deletion_request_states` → lógica del SP con `UPDLOCK/HOLDLOCK`.
- `ancestors` → columna de ruta o CTE recursiva. `statusHistory` embebido → tabla hija `asset_status_history`.
- `kardex_logs` append-only → revocar UPDATE/DELETE o trigger.
- `imageData` (data-URL < 1.1 MiB) → `NVARCHAR(MAX)` o `VARBINARY(MAX)`; `searchTerms` → columna calculada + LIKE o FULLTEXT con semántica AND.
- PBKDF2 sigue en cliente Dart (salvo mover verificación a servidor): conservar columnas salt/hash/iteraciones.
- Los 3 listeners `.snapshots()` requieren polling o SignalR.

Artefactos SQL van en `database/` (crear; p. ej. `database/init.sql`).

## Gotchas

- Sin CI: verificar con `flutter analyze && flutter test` antes de terminar.
- El README dice "49 pruebas": desactualizado (128 hoy).
- Idioma de dominio/UI: español; mantener los strings de usuario en español.
- `lib/firebase_options.dart` es generado por flutterfire CLI: no editarlo a mano.
