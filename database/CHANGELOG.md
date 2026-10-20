# Changelog de Migraciones — MacsaCMMS

> Registra CADA script SQL ejecutado en producción. Nunca borrar entradas.

---

## [2026-10-20] 2026-10-20_blindaje_ot_abierta_activo.sql
- Actualiza `dbo.uspOrdenTrabajoCrear` con validación estricta de OT previa abierta por activo.
- Rechaza creación de OT si el equipo tiene una orden en estado `pending`, `inProgress` o `paused`.
- Asigna permisos de ejecución a `macsa_app`.

## [2026-09-28] init.sql — Carga Inicial
- Estructura completa de la base de datos (tablas, SPs, índices)
- Datos seed iniciales (roles, permisos, área raíz)
- **Ejecutado por:** Nixon

## [2026-09-28] crear_usuario_admin.sql
- Crea el usuario administrador inicial (ADMIN)

## [2026-09-28] Migraciones incrementales aplicadas
Los siguientes scripts fueron ejecutados como parte del despliegue inicial:
- `migracion_usuarios_y_reset_password.sql`
- `migracion_areas_crud_kardex.sql`
- `migracion_transferencia_subarbol_completo.sql`
- `migracion_preventivo_jerarquico.sql`
- `migracion_preventivo_v2.sql`
- `migracion_preventivo_v3_indicadores_blindaje.sql`
- `migracion_plan_preventivo_unico_por_equipo.sql`
- `migracion_ot_preventiva_visibilidad.sql`
- `migracion_ots_preventivas_consolidacion.sql`
- `migracion_disponibilidad_operacion.sql`
- `migracion_actualizaciones_android.sql`
- `migracion_almacenamiento_imagenes_disco.sql`
- `fase2_preventivos_ejecucion_fechas.sql`
- `fase3_averias_ots_correctivas.sql`
- `fase4_dashboard_indicadores_trazabilidad.sql`
- `alter_preventive_frequencies.sql`
- `migrate_permissions.sql`
- `fix_all_mojibake.sql`
- `fix_disponibilidad_sql.sql`
- `fix_uspUsuarioObtenerParaLogin.sql`

---

<!-- NUEVAS MIGRACIONES VAN AQUÍ ARRIBA, EN ORDEN CRONOLÓGICO DESCENDENTE -->
