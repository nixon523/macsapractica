# AGENTS.md — Sistema CMMS Grupo Macsa

Sistema CMMS de **Grupo Macsa** (gestión de mantenimiento). Cliente **Flutter** con **Clean Architecture + MVVM**, backend **API REST Node.js** y persistencia en **SQL Server**. Detalle integral y fuentes de verdad en `README.md`.

> Backend actual: `Flutter → API REST (macsa-api, repo externo) → SQL Server (MacsaCMMS)`. El antiguo backend Firestore ya no está en runtime y no aparece en `pubspec.yaml`, `lib/main.dart` ni `lib/`. Los restos de nomenclatura Firestore son deuda técnica documentada en `README.md` §11.

## Comandos

```bash
flutter pub get
flutter analyze   # 2026-11-27: errores preexistentes en el flujo OT sin commitear (work_order_detail_view.dart, work_order_report_pdf_builder.dart); no introducir nuevos errores/warnings
flutter test      # 47 archivos de test, ~208 casos declarados; offline con mocktail, sin red ni Firebase
flutter test test/features/assets/data/models/asset_model_test.dart  # un archivo
flutter test --name "transfer"                                       # por nombre
```

- Ejecutar: `flutter run -d chrome` / `-d windows`; override de API: `flutter run -d chrome --dart-define=API_URL=http://localhost:3000/api`.
- Builds: `flutter build apk` / `flutter build web`.
- API Node (externa): `C:\Users\user\Documents\macsa-api`, `npm run dev` en `:3000`.
- SQL: aplicar migraciones incrementales desde `database/` (nunca reejecutar `init.sql` sobre una BD ya migrada sin revisar los parches); ver `database/CHANGELOG.md` y `REGLAS_PRODUCCION.md`.
- Utilidades: `dart run tool/hash_password.dart`, `node scripts/audit_sp_parameters.js`.

## Arquitectura

- Entrada: `lib/main.dart` → `AppVersion.initialize()` → `SessionManager.instance.init()` → `configureDependencies()` → `MacsaApp`. **No hay `Firebase.initializeApp`.**
- **La DI es manual**: todo use case/repositorio/ViewModel nuevo DEBE registrarse en `lib/app/di/get_it.dart` (133 registros; `registerLazySingleton` / `registerFactory`) o nunca se instanciará. Los providers globales están en `lib/app/di/providers.dart` (18).
- Navegación: `lib/app/router/app_router.dart` con `Navigator` clásico (no `go_router`); la navegación principal ocurre en `lib/app/screens/main_shell_screen.dart` (13 secciones, 4 grupos, badges, inactividad 55/60 min).
- Features en `lib/features/<módulo>/{domain,data,presentation}`:
  - `domain`: Dart puro, sin Flutter ni red (entidades, contratos, use cases).
  - `data`: modelos JSON (`fromJson`/`toJson`, compatibles con claves `PascalCase`), datasources REST (uno por módulo) e implementaciones de repositorio. `AssetLocalDataSource` es un caché en memoria por área, no persistente.
  - `presentation`: ViewModels `ChangeNotifier` que consumen SOLO use cases; Views con `Provider`.
- Módulos vigentes: `assets`, `asset_deletion`, `auth_permissions`, `breakdown_reports`, `dashboard`, `employees`, `kardex`, `operation_reports`, `preventive_schedules`, `work_orders`, `app_update`.
- Cliente HTTP: `lib/core/network/api_client.dart` (JWT Bearer, timeout 15 s, multipart, resolución de URL base y errores). Rutas centralizadas en `lib/core/network/api_endpoints.dart` (74). Sesión JWT en `SharedPreferences` vía `lib/core/network/session_manager.dart`.
- Tiempo "real": polling en ViewModels (averías/mis reportes/OTs 10 s, resets 15 s, versión Android 30 s) + notificaciones locales; no hay `.snapshots()`.

## API REST (repo externo)

- Código: `C:\Users\user\Documents\macsa-api`. Rutas en `src/routes/*.routes.js`, llamadas a SP en `src/services/*.service.js`.
- Autenticación: login propio contra SQL, **PBKDF2-HMAC-SHA256 server-side** (`src/security/password.js`, 16 B salt / 32 B hash / 20.000 iteraciones), JWT (`src/security/jwt.js`), sesiones concurrentes limitadas a 2 con política FIFO y `jti`.
- RBAC: 6 roles (`admin`, `jefe`, `jefe_area`, `tecnico`, `reportador`, `lector`) y 22 permisos `modulo.accion` (`src/security/rolePermissions.js`, middleware `permission.middleware.js`). `admin` pasa todas las verificaciones; la UI usa `AuthViewModel.hasPermission`.
- Bloqueo: 5 intentos fallidos → 15 min. Reset genera contraseña temporal y registra la solicitud.
- La API expone alias en inglés de las rutas en español; el cliente consume las españolas.

## SQL Server y reglas de integridad

- Fuente ejecutable: `database/init.sql` (baseline generado el 2026-11-13 desde `scripts/sql_modules/01..07`), con 29 tablas `dbo.*`, ~104 SPs, TVPs, funciones, índices, checks, trigger y seed. Encima se aplican los parches cronológicos en `database/` (hasta 2026-11-27).
- Nombres reales en español: `Activo`, `Area`, `Usuario`, `SesionUsuario`, `SolicitudBaja`, `CandadoBaja`, `BitacoraKardex`, `OrdenTrabajo`, `ReporteAveria`, `PlanPreventivo`, `ReporteOperacionDiaria`, `Empleado`, `Puesto`, etc.
- IDs con significado de negocio (PKs naturales): áreas `A001`…`A030`, activos `{área}-00N` y `{padre}-NN`, OTs `OT-{año}-NNNN`, preventivos `PM-{año}-NNNN`.
- Contadores en `dbo.Contador` / `Area.ContadorActivos` / `Activo.ContadorHijos`, reclamados con `UPDLOCK, HOLDLOCK` **dentro de la misma transacción** del SP.
- Candado de bajas: `dbo.CandadoBaja` se lee con `UPDLOCK, HOLDLOCK` en toda mutación de un activo (alta, edición, traspaso, reactivación, cambio de estado, resolución de baja).
- `BitacoraKardex` es append-only por trigger (`TR_BitacoraKardex_SoloInsercion`); cada mutación registra su evento en la misma transacción. No hay borrado físico de negocio: las bajas son lógicas (`Estado = 'deleted'` / `'inactive'`).
- `Activo` e `HistorialEstadoActivo`: campos jerárquicos inmutables (`AreaId`, `CodigoActivoPadre`, `Nivel`, `RutaAncestros`, `Serie`), enums CHECK y `TextoBusqueda` calculada persistida para búsqueda AND. `trActivo_Inmutable` vive en `fix_disponibilidad_sql.sql`.
- Usuario: prohibida cualquier columna de contraseña en claro; `Username` inmutable. Contraseñas: salt/hash/iteraciones.
- Transferencia: duplica el subárbol al área destino con nuevos IDs y desactiva el origen (`transferredDeactivated` + `TraspasadoACodigo`) en una transacción. Reactivación solo desde ese estado.
- SPs se nombran `usp...`; cada consulta/transacción del antiguo datasource corresponde hoy a un SP. Catálogo completo en `README.md` §7.3.

## Gotchas

- Sin CI: verificar `flutter analyze && flutter test` antes de terminar.
- Idioma de dominio/UI: español; mantener los strings de usuario en español.
- `pubspec.yaml` = `1.0.4+5`; `AppVersion` tiene fallback `1.0.3+4` corregido en runtime con `package_info_plus`.
- `README.md` §11 contiene el estado de migración y deuda técnica: documentación heredada, `CHANGELOG.md` desactualizado, residuos Firestore en comentarios/modelos, `init.sql` no re-ejecutable tal cual, parche 2026-11-27 sin commitear, `.gitignore` sin `.env`.
- No editar artefactos generados ni consolidados SQL sin revisar los parches posteriores: `database/init.sql`, `deploy_produccion_2026-11-13.sql` y `update_produccion_2026-11-18.sql` se regeneran desde `scripts/sql_modules/` y `scripts/build_*.js`.
- No hay `lib/firebase_options.dart` (no editar/generar). No hay `seed_firestore.ps1` ni `firestore.rules` / `firestore.indexes.json`.
- Credenciales de demo: `ADMIN/ADMIN123`, `NMENDEZ/ADMIN123`, `JEFE/ADMIN123` (solo demo/desarrollo). Ver `GUIA_DEMO_GERENCIA_15MIN.md`.
