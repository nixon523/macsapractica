-- ----------------------------------------------------------------------------
-- 19. SEGURIDAD Y CONCESIÓN DE PERMISOS PARA LA API (macsa_app)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'macsa_app')
BEGIN
    CREATE USER [macsa_app] FOR LOGIN [macsa_app];
    PRINT N'Usuario de base de datos macsa_app creado.';
END;
GO

GRANT EXECUTE ON SCHEMA::dbo TO [macsa_app];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [macsa_app];
GO

PRINT N'Permisos de ejecución y acceso a datos concedidos a macsa_app.';
GO

-- ----------------------------------------------------------------------------
-- 20. SIEMBRA DE DATOS OFICIALES PARA PRODUCCIÓN
-- ----------------------------------------------------------------------------
PRINT N'============================================================================';
PRINT N'Iniciando siembra de datos maestros de producción...';
PRINT N'============================================================================';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- 20.1 Catálogo de Roles (5 Roles Jerárquicos)
    INSERT INTO dbo.Rol (CodigoRol, Nombre)
    VALUES
        (N'admin',      N'Administrador General'),
        (N'jefe',       N'Jefe de Mantenimiento'),
        (N'jefe_area',  N'Jefe de Área / Operaciones'),
        (N'reportador', N'Supervisor (Reportador)'),
        (N'lector',     N'Gerente (Solo Lectura / Auditoría)');

    -- 20.2 Catálogo de Permisos Granulares (20 Permisos)
    INSERT INTO dbo.Permiso (CodigoPermiso)
    VALUES
        (N'dashboard.view'),
        (N'asset.view'),
        (N'asset.create'),
        (N'asset.edit'),
        (N'asset.transfer'),
        (N'asset.delete.request'),
        (N'asset.delete.approve'),
        (N'work_order.view'),
        (N'work_order.create'),
        (N'work_order.print'),
        (N'preventive.view'),
        (N'preventive.manage'),
        (N'breakdown.report'),
        (N'breakdown.view'),
        (N'breakdown.manage'),
        (N'operation_report.view'),
        (N'operation_report.edit'),
        (N'kardex.view'),
        (N'user.manage'),
        (N'employee.manage');

    -- 20.3 Matriz de Permisos por Rol (dbo.RolPermiso)
    -- admin: Acceso Total
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    SELECT N'admin', CodigoPermiso FROM dbo.Permiso;

    -- jefe: Gestión Técnica Completa (excepto user.manage y asset.delete.approve)
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'jefe', N'dashboard.view'),
        (N'jefe', N'asset.view'),
        (N'jefe', N'asset.create'),
        (N'jefe', N'asset.edit'),
        (N'jefe', N'asset.transfer'),
        (N'jefe', N'asset.delete.request'),
        (N'jefe', N'work_order.view'),
        (N'jefe', N'work_order.create'),
        (N'jefe', N'work_order.print'),
        (N'jefe', N'preventive.view'),
        (N'jefe', N'preventive.manage'),
        (N'jefe', N'breakdown.report'),
        (N'jefe', N'breakdown.view'),
        (N'jefe', N'breakdown.manage'),
        (N'jefe', N'operation_report.view'),
        (N'jefe', N'operation_report.edit'),
        (N'jefe', N'kardex.view'),
        (N'jefe', N'employee.manage');

    -- jefe_area: Operaciones y Supervisión Local
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'jefe_area', N'dashboard.view'),
        (N'jefe_area', N'asset.view'),
        (N'jefe_area', N'work_order.view'),
        (N'jefe_area', N'work_order.print'),
        (N'jefe_area', N'preventive.view'),
        (N'jefe_area', N'breakdown.report'),
        (N'jefe_area', N'breakdown.view'),
        (N'jefe_area', N'operation_report.view'),
        (N'jefe_area', N'operation_report.edit');

    -- reportador: Reporte y Seguimiento de Fallas
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'reportador', N'breakdown.report'),
        (N'reportador', N'breakdown.view');

    -- lector: Solo Lectura, Reportes y Auditoría
    INSERT INTO dbo.RolPermiso (CodigoRol, CodigoPermiso)
    VALUES
        (N'lector', N'dashboard.view'),
        (N'lector', N'asset.view'),
        (N'lector', N'work_order.view'),
        (N'lector', N'work_order.print'),
        (N'lector', N'preventive.view'),
        (N'lector', N'kardex.view'),
        (N'lector', N'breakdown.view'),
        (N'lector', N'operation_report.view');

    -- 20.4 Las 30 Áreas Oficiales de Grupo Macsa
    INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, Activo, CreadoEn)
    VALUES 
        ('A001', N'ADMINISTRACION',                 'CC-37', 0, 1, SYSUTCDATETIME()),
        ('A002', N'AREA DE DESPACHO',               'CC-38', 0, 1, SYSUTCDATETIME()),
        ('A003', N'EMPAQUE - MASTERIZADO',          'CC-39', 0, 1, SYSUTCDATETIME()),
        ('A004', N'CAFETERIA',                      'CC-40', 0, 1, SYSUTCDATETIME()),
        ('A005', N'CLASIFICADO',                    'CC-41', 0, 1, SYSUTCDATETIME()),
        ('A006', N'COCINADO',                       'CC-42', 0, 1, SYSUTCDATETIME()),
        ('A007', N'CONTABILIDAD',                   'CC-43', 0, 1, SYSUTCDATETIME()),
        ('A008', N'DESCABEZADO',                    'CC-44', 0, 1, SYSUTCDATETIME()),
        ('A009', N'EMPAQUE BLOCK',                  'CC-45', 0, 1, SYSUTCDATETIME()),
        ('A010', N'EMPAQUE IQF',                    'CC-46', 0, 1, SYSUTCDATETIME()),
        ('A011', N'GERENCIA',                       'CC-47', 0, 1, SYSUTCDATETIME()),
        ('A012', N'IMPORT & EXPORT',                'CC-48', 0, 1, SYSUTCDATETIME()),
        ('A013', N'INOCUIDAD',                      'CC-49', 0, 1, SYSUTCDATETIME()),
        ('A014', N'RECEPCION',                      'CC-50', 0, 1, SYSUTCDATETIME()),
        ('A015', N'LABORATORIO',                    'CC-51', 0, 1, SYSUTCDATETIME()),
        ('A016', N'LAVANDERIA',                     'CC-52', 0, 1, SYSUTCDATETIME()),
        ('A017', N'MANTENIMIENTO',                  'CC-53', 0, 1, SYSUTCDATETIME()),
        ('A018', N'PLANTA DE HIELO',                'CC-54', 0, 1, SYSUTCDATETIME()),
        ('A019', N'POES',                           'CC-55', 0, 1, SYSUTCDATETIME()),
        ('A020', N'AREA ENVIO-PRODUCTO TERMINADO',  'CC-56', 0, 1, SYSUTCDATETIME()),
        ('A021', N'RECEPCION PLANTA',               'CC-57', 0, 1, SYSUTCDATETIME()),
        ('A022', N'RECURSOS HUMANOS',               'CC-58', 0, 1, SYSUTCDATETIME()),
        ('A023', N'SALMUERA',                       'CC-59', 0, 1, SYSUTCDATETIME()),
        ('A024', N'SALUD & SEGURIDAD OCUPACIONAL',  'CC-60', 0, 1, SYSUTCDATETIME()),
        ('A025', N'TIC''S',                         'CC-61', 0, 1, SYSUTCDATETIME()),
        ('A026', N'VIGILANCIA',                     'CC-62', 0, 1, SYSUTCDATETIME()),
        ('A027', N'PELADO',                         'CC-63', 0, 1, SYSUTCDATETIME()),
        ('A028', N'TRATAMIENTO-PELADO',             'CC-64', 0, 1, SYSUTCDATETIME()),
        ('A029', N'LIMPIEZA -EXTERIORES',           'CC-65', 0, 1, SYSUTCDATETIME()),
        ('A030', N'PRODUCCION',                     'CC-98', 0, 1, SYSUTCDATETIME());

    -- 20.5 Contadores Transaccionales
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero)
    VALUES
        ('areas', 31),
        ('work_orders', 1),
        ('preventive_schedules', 1);

    -- 20.6 Catálogo Inicial de Puestos / Cargos
    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
    VALUES
        (N'Desarrollador',                        0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Jefe de Mantenimiento',                1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Supervisor de Mantenimiento',          1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Mecánico Industrial',          1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Electricista / Automatización', 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico en Refrigeración y Calderas',  1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Electromecánico',              1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Técnico Soldador / Estructuras',       1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Auxiliar de Mantenimiento',            1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Jefe de Área / Operaciones',           0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Supervisor de Producción',             0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Gerente General',                      0, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'Gerente de Operaciones',               0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    -- 20.7 Empleado Administrador Oficial: Nixon Manuel Mendez Galo
    DECLARE @PuestoDevId INT;
    SELECT @PuestoDevId = PuestoId FROM dbo.Puesto WHERE Nombre = N'Desarrollador';

    INSERT INTO dbo.Empleado
        (NombreCompleto, PuestoId, Puesto, AreaId, NombreArea, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
    VALUES
        (N'Nixon Manuel Mendez Galo', @PuestoDevId, N'Desarrollador', 'A025', N'TIC''S', 0, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

    DECLARE @AdminEmpleadoId INT = SCOPE_IDENTITY();

    -- 20.8 Usuario Administrador Oficial: NMENDEZ (Contraseña: ADMIN123)
    -- Hash PBKDF2-HMAC-SHA256 con 20.000 iteraciones verificado
    INSERT INTO dbo.Usuario (
        NombreUsuario, NombreCompleto, CodigoRol, EmpleadoId,
        PasswordSalt, PasswordHash, IteracionesPassword,
        Deshabilitado, DebeCambiarPassword, SolicitudReinicioPassword,
        IntentosFallidos, BloqueadoHasta, CreadoEn
    )
    VALUES (
        N'NMENDEZ',
        N'Nixon Manuel Mendez Galo',
        N'admin',
        @AdminEmpleadoId,
        N'W434BLHgQkv2WatVO1Hzlw==',
        N'QdrlzoourSpIVUo3ngYVav0mKo4VfQFvlja40iuXbAU=',
        20000,
        0, 0, 0,
        0, NULL, SYSUTCDATETIME()
    );

    DECLARE @AdminUserId INT = SCOPE_IDENTITY();

    -- 20.9 Asignar Todos los Permisos al Administrador
    INSERT INTO dbo.UsuarioPermiso (UsuarioId, CodigoPermiso)
    SELECT @AdminUserId, CodigoPermiso FROM dbo.Permiso;

    -- 20.10 Registro Inicial de Auditoría en Bitácora Kardex
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (
        @AdminUserId,
        N'NMENDEZ',
        'SYSTEM_INITIALIZED',
        'USERS',
        'MacsaCMMS',
        N'Inicialización oficial de base de datos en producción. 30 Áreas Oficiales sembradas, esquema relacional desplegado y Administrador General NMENDEZ registrado.'
    );

    COMMIT TRANSACTION;
    PRINT N'============================================================================';
    PRINT N'¡DESPLIEGUE A PRODUCCIÓN COMPLETADO CON ÉXITO!';
    PRINT N'30 Áreas Oficiales creadas (A001 a A030).';
    PRINT N'13 Puestos de catálogo registrados.';
    PRINT N'Empleado Nixon Manuel Mendez Galo registrado en TIC''S.';
    PRINT N'Usuario Administrador NMENDEZ activo con acceso total.';
    PRINT N'Base de datos limpia de datos de prueba, lista para operación real.';
    PRINT N'============================================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error durante la inicialización de datos de producción:';
    THROW;
END CATCH;
GO
