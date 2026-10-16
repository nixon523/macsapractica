/* ============================================================================
   MACSA CMMS - Grupo Macsa
   database/preparar_demo_gerencia.sql
   
   PROPÓSITO:
   - Limpieza segura de datos de prueba previos (reseteo ordenado).
   - Inserción de las 30 ÁREAS OFICIALES de Grupo Macsa con sus Códigos y Centros de Costo.
   - Inserción de 2 ACTIVOS MAESTROS con Jerarquía Completa de 4 Niveles:
       * A003-001 (Área 003: Empaque - Masterizado)
       * A005-001 (Área 005: Clasificado)
   - Creación de Plan Preventivo de Demostración para A005-001.
   - Creación / Aseguramiento de Usuarios de Demostración (ADMIN y JEFE).
   - Reseteo de Contadores de Correlativos (OTs, PMs).
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT N'🧹 1. Iniciando limpieza segura de datos de prueba...';

    -- 1.1 Eliminar detalles de OTs
    IF OBJECT_ID(N'dbo.MaterialOrdenTrabajo', N'U') IS NOT NULL DELETE FROM dbo.MaterialOrdenTrabajo;
    IF OBJECT_ID(N'dbo.TipoTrabajoOrdenTrabajo', N'U') IS NOT NULL DELETE FROM dbo.TipoTrabajoOrdenTrabajo;

    -- 1.2 Romper todas las referencias cruzadas entre tablas
    IF OBJECT_ID(N'dbo.PlanPreventivo', N'U') IS NOT NULL UPDATE dbo.PlanPreventivo SET UltimaOrdenTrabajoId = NULL;
    IF OBJECT_ID(N'dbo.OrdenTrabajo', N'U') IS NOT NULL UPDATE dbo.OrdenTrabajo SET ReporteId = NULL, PlanPreventivoId = NULL;
    IF OBJECT_ID(N'dbo.ReporteAveria', N'U') IS NOT NULL UPDATE dbo.ReporteAveria SET OrdenTrabajoId = NULL;

    -- 1.3 Eliminar transacciones de órdenes y reportes
    IF OBJECT_ID(N'dbo.ReporteAveria', N'U') IS NOT NULL DELETE FROM dbo.ReporteAveria;
    IF OBJECT_ID(N'dbo.OrdenTrabajo', N'U') IS NOT NULL DELETE FROM dbo.OrdenTrabajo;

    -- 1.4 Eliminar detalles y cabecera de Planes Preventivos
    IF OBJECT_ID(N'dbo.PlanPreventivoMaterial', N'U') IS NOT NULL DELETE FROM dbo.PlanPreventivoMaterial;
    IF OBJECT_ID(N'dbo.MaterialPreventivo', N'U') IS NOT NULL DELETE FROM dbo.MaterialPreventivo;
    IF OBJECT_ID(N'dbo.PlanPreventivoActividad', N'U') IS NOT NULL DELETE FROM dbo.PlanPreventivoActividad;
    IF OBJECT_ID(N'dbo.PlanPreventivo', N'U') IS NOT NULL DELETE FROM dbo.PlanPreventivo;

    -- 1.5 Eliminar estados, solicitudes y auditoría (deshabilitando triggers inmutables temporalmente)
    IF OBJECT_ID(N'dbo.SolicitudBaja', N'U') IS NOT NULL DELETE FROM dbo.SolicitudBaja;
    IF OBJECT_ID(N'dbo.CandadoBaja', N'U') IS NOT NULL DELETE FROM dbo.CandadoBaja;
    IF OBJECT_ID(N'dbo.HistorialEstadoActivo', N'U') IS NOT NULL DELETE FROM dbo.HistorialEstadoActivo;
    
    IF OBJECT_ID(N'dbo.BitacoraKardex', N'U') IS NOT NULL 
    BEGIN
        ALTER TABLE dbo.BitacoraKardex DISABLE TRIGGER ALL;
        DELETE FROM dbo.BitacoraKardex;
        ALTER TABLE dbo.BitacoraKardex ENABLE TRIGGER ALL;
    END;

    IF OBJECT_ID(N'dbo.ReporteOperacionDiaria', N'U') IS NOT NULL DELETE FROM dbo.ReporteOperacionDiaria;
    IF OBJECT_ID(N'dbo.SolicitudReinicioPassword', N'U') IS NOT NULL DELETE FROM dbo.SolicitudReinicioPassword;

    -- 1.6 Eliminar Activos y Áreas previas
    IF OBJECT_ID(N'dbo.Activo', N'U') IS NOT NULL 
    BEGIN
        ALTER TABLE dbo.Activo DISABLE TRIGGER ALL;
        DELETE FROM dbo.Activo;
        ALTER TABLE dbo.Activo ENABLE TRIGGER ALL;
    END;

    IF OBJECT_ID(N'dbo.Area', N'U') IS NOT NULL DELETE FROM dbo.Area;

    PRINT N'✅ Limpieza completada exitosamente.';

    -- ========================================================================
    -- 2. REINICIAR CONTADORES
    -- ========================================================================
    PRINT N'🔢 2. Reiniciando contadores de correlativos...';
    
    DELETE FROM dbo.Contador;
    INSERT INTO dbo.Contador (Nombre, SiguienteNumero) VALUES
        ('areas', 31),
        ('work_orders', 1),
        ('preventive_schedules', 1);

    -- ========================================================================
    -- 3. ASEGURAR USUARIOS PARA LA PRESENTACIÓN
    -- ========================================================================
    PRINT N'👤 3. Configurando usuarios de demostración...';

    -- Clave por defecto para la demo: ADMIN123 (PBKDF2-HMAC-SHA256, 20k iteraciones)
    DECLARE @Salt NVARCHAR(64) = N'esPJbm6PdewlxkEviSaS2Q==';
    DECLARE @Hash NVARCHAR(128) = N'xEHs3B7nYyZOFuZd7lB8QzY4J04Kxgfw9xRUu9OcMIg=';

    -- Asegurar Roles
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE CodigoRol = 'admin')
        INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES ('admin', N'Administrador');
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE CodigoRol = 'jefe')
        INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES ('jefe', N'Jefe de Mantenimiento');
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE CodigoRol = 'reportador')
        INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES ('reportador', N'Operador / Reportador');
    IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE CodigoRol = 'lector')
        INSERT INTO dbo.Rol (CodigoRol, Nombre) VALUES ('lector', N'Lector');

    -- Usuario 1: ADMIN (Super Administrador)
    IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE NombreUsuario = 'ADMIN')
    BEGIN
        UPDATE dbo.Usuario
           SET NombreCompleto = N'Administrador General',
               CodigoRol = 'admin',
               PasswordSalt = @Salt,
               PasswordHash = @Hash,
               IteracionesPassword = 20000,
               Deshabilitado = 0,
               DebeCambiarPassword = 0,
               IntentosFallidos = 0,
               BloqueadoHasta = NULL
         WHERE NombreUsuario = 'ADMIN';
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Usuario (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash, IteracionesPassword, Deshabilitado, DebeCambiarPassword, IntentosFallidos, CreadoEn)
        VALUES ('ADMIN', N'Administrador General', 'admin', @Salt, @Hash, 20000, 0, 0, 0, SYSUTCDATETIME());
    END;

    -- Usuario 2: JEFE (Ing. Carlos Mendoza - Jefe de Mantenimiento)
    IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE NombreUsuario = 'JEFE')
    BEGIN
        UPDATE dbo.Usuario
           SET NombreCompleto = N'Ing. Carlos Mendoza (Jefe Mantenimiento)',
               CodigoRol = 'jefe',
               PasswordSalt = @Salt,
               PasswordHash = @Hash,
               IteracionesPassword = 20000,
               Deshabilitado = 0,
               DebeCambiarPassword = 0,
               IntentosFallidos = 0,
               BloqueadoHasta = NULL
         WHERE NombreUsuario = 'JEFE';
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Usuario (NombreUsuario, NombreCompleto, CodigoRol, PasswordSalt, PasswordHash, IteracionesPassword, Deshabilitado, DebeCambiarPassword, IntentosFallidos, CreadoEn)
        VALUES ('JEFE', N'Ing. Carlos Mendoza (Jefe Mantenimiento)', 'jefe', @Salt, @Hash, 20000, 0, 0, 0, SYSUTCDATETIME());
    END;

    -- ========================================================================
    -- 4. INSERTAR LAS 30 ÁREAS OFICIALES DE GRUPO MACSA
    -- ========================================================================
    PRINT N'🏭 4. Insertando las 30 Áreas Oficiales de Grupo Macsa...';

    INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, CreadoEn)
    VALUES 
        ('A001', N'ADMINISTRACION',                 'CC-37', 0, SYSUTCDATETIME()),
        ('A002', N'AREA DE DESPACHO',               'CC-38', 0, SYSUTCDATETIME()),
        ('A003', N'EMPAQUE - MASTERIZADO',          'CC-39', 1, SYSUTCDATETIME()),
        ('A004', N'CAFETERIA',                      'CC-40', 0, SYSUTCDATETIME()),
        ('A005', N'CLASIFICADO',                    'CC-41', 1, SYSUTCDATETIME()),
        ('A006', N'COCINADO',                       'CC-42', 0, SYSUTCDATETIME()),
        ('A007', N'CONTABILIDAD',                   'CC-43', 0, SYSUTCDATETIME()),
        ('A008', N'DESCABEZADO',                    'CC-44', 0, SYSUTCDATETIME()),
        ('A009', N'EMPAQUE BLOCK',                  'CC-45', 0, SYSUTCDATETIME()),
        ('A010', N'EMPAQUE IQF',                    'CC-46', 0, SYSUTCDATETIME()),
        ('A011', N'GERENCIA',                       'CC-47', 0, SYSUTCDATETIME()),
        ('A012', N'IMPORT & EXPORT',                'CC-48', 0, SYSUTCDATETIME()),
        ('A013', N'INOCUIDAD',                      'CC-49', 0, SYSUTCDATETIME()),
        ('A014', N'RECEPCION',                      'CC-50', 0, SYSUTCDATETIME()),
        ('A015', N'LABORATORIO',                    'CC-51', 0, SYSUTCDATETIME()),
        ('A016', N'LAVANDERIA',                     'CC-52', 0, SYSUTCDATETIME()),
        ('A017', N'MANTENIMIENTO',                  'CC-53', 0, SYSUTCDATETIME()),
        ('A018', N'PLANTA DE HIELO',                'CC-54', 0, SYSUTCDATETIME()),
        ('A019', N'POES',                           'CC-55', 0, SYSUTCDATETIME()),
        ('A020', N'AREA ENVIO-PRODUCTO TERMINADO',  'CC-56', 0, SYSUTCDATETIME()),
        ('A021', N'RECEPCION PLANTA',               'CC-57', 0, SYSUTCDATETIME()),
        ('A022', N'RECURSOS HUMANOS',               'CC-58', 0, SYSUTCDATETIME()),
        ('A023', N'SALMUERA',                       'CC-59', 0, SYSUTCDATETIME()),
        ('A024', N'SALUD & SEGURIDAD OCUPACIONAL',  'CC-60', 0, SYSUTCDATETIME()),
        ('A025', N'TIC''S',                         'CC-61', 0, SYSUTCDATETIME()),
        ('A026', N'VIGILANCIA',                     'CC-62', 0, SYSUTCDATETIME()),
        ('A027', N'PELADO',                         'CC-63', 0, SYSUTCDATETIME()),
        ('A028', N'TRATAMIENTO-PELADO',             'CC-64', 0, SYSUTCDATETIME()),
        ('A029', N'LIMPIEZA -EXTERIORES',           'CC-65', 0, SYSUTCDATETIME()),
        ('A030', N'PRODUCCION',                     'CC-98', 0, SYSUTCDATETIME());

    -- ========================================================================
    -- 5. INSERTAR ACTIVOS CON JERARQUÍA COMPLETA DE 4 NIVELES
    -- ========================================================================
    PRINT N'⚙️ 5. Insertando Activos Maestros con 4 Niveles de Jerarquía...';

    -- ════════════════════════════════════════════════════════════════════════
    -- ACTIVO 1: ÁREA A003 - LÍNEA AUTOMÁTICA DE EMPAQUE Y MASTERIZADO
    -- ════════════════════════════════════════════════════════════════════════
    -- Nivel 1: Equipo Raíz
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES (
        'A003-001', N'Línea Automática de Empaque y Masterizado', N'Bosch Packaging / Syntegon', N'Pack 301-Master',
        'A003', N'EST-EMP-01', N'SN-EMP-2026-001',
        'equipment', N'', NULL, 'active', 4,
        N'{"velocidad_nominal":"120 cajas/min","voltaje":"480V Trifásico","potencia_instalada":"45 kW","presion_aire":"6.0 Bar","plc_controlador":"Siemens S7-1500"}',
        SYSUTCDATETIME()
    );

    -- Nivel 2: Sub-equipos de A003-001
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-01', N'Formadora Automática de Cajas Master', N'Wexxar Bel', N'WF-30T',
        'A003', N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 0,
        N'{"capacidad_almacen_carton":"150 planchas","tipo_caja":"RSC Standard","adhesivo":"Cinta autoadhesiva 50mm"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-02', N'Envasadora Vertical Multicabezal', N'Ishida', N'CCW-R2-214W',
        'A003', N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 0,
        N'{"numero_cabezales":"14 cabezales","precision":"0.1 g","volumen_pesaje":"3000 cc"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03', N'Robot Encartonador Pick & Place', N'Fanuc Robotics', N'M-20iD/25',
        'A003', N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 2,
        N'{"grados_libertad":"6 Ejes","carga_maxima":"25 kg","alcance_radio":"1831 mm"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-04', N'Precintadora y Selladora Hot Melt', N'Nordson', N'ProBlue 7',
        'A003', N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 1,
        N'{"temperatura_operacion":"175 °C","capacidad_tanque":"7 kg","mangueras_activas":"2"}',
        SYSUTCDATETIME()
    );

    -- Nivel 3: Partes (Hijos de Sub-equipos)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-03-01', N'Módulo de Garra de Succión por Vacío', N'Schmalz', N'SPG-200',
        'A003', N'EST-EMP-01', NULL,
        'part', N'A003-001/A003-001-03', 'A003-001-03', 'active', 2,
        N'{"nivel_vacio_max":"-85 kPa","caudal_aspiracion":"120 l/min"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03-02', N'Servomotor de Eje Principal Z', N'Fanuc', N'Alpha-iF 8/4000',
        'A003', N'EST-EMP-01', NULL,
        'part', N'A003-001/A003-001-03', 'A003-001-03', 'active', 0,
        N'{"torque_continuo":"8 Nm","velocidad_max":"4000 RPM","encoder":"Absoluto 24-bit"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-04-01', N'Unidad Aplicadora de Adhesivo Termofusible', N'Nordson', N'SolidBlue S',
        'A003', N'EST-EMP-01', NULL,
        'part', N'A003-001/A003-001-04', 'A003-001-04', 'active', 1,
        N'{"presion_hidraulica_max":"100 psi","voltaje_calefactor":"230V"}',
        SYSUTCDATETIME()
    );

    -- Nivel 4: Sub-partes (Hijos de Partes)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-03-01-01', N'Ventosa de Succión Grado Alimentario Ø50mm', N'Schmalz', N'SAB-50-SI',
        'A003', N'EST-EMP-01', NULL,
        'subPart', N'A003-001/A003-001-03/A003-001-03-01', 'A003-001-03-01', 'active', 0,
        N'{"material":"Silicona FDA Blanca","diametro_nominal":"50 mm","carrera_fuelle":"15 mm"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03-01-02', N'Generador de Vacío Eyector Venturi', N'SMC', N'ZH10BS-06-06',
        'A003', N'EST-EMP-01', NULL,
        'subPart', N'A003-001/A003-001-03/A003-001-03-01', 'A003-001-03-01', 'active', 0,
        N'{"diametro_boquilla":"1.0 mm","consumo_aire":"46 L/min ANR"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-04-01-01', N'Boquilla Dosificadora Neumática Hot Melt 0.4mm', N'Nordson', N'Saturn-04',
        'A003', N'EST-EMP-01', NULL,
        'subPart', N'A003-001/A003-001-04/A003-001-04-01', 'A003-001-04-01', 'active', 0,
        N'{"orificio":"0.4 mm / 0.016 in","angulo_dispersion":"90 grados"}',
        SYSUTCDATETIME()
    );


    -- ════════════════════════════════════════════════════════════════════════
    -- ACTIVO 2: ÁREA A005 - MÁQUINA CLASIFICADORA ÓPTICA INDUSTRIAL
    -- ════════════════════════════════════════════════════════════════════════
    -- Nivel 1: Equipo Raíz
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES (
        'A005-001', N'Máquina Clasificadora Óptica Industrial', N'Bühler Sortex', N'Sortex S-Ultra 400',
        'A005', N'EST-CLAS-01', N'SN-CLAS-2026-001',
        'equipment', N'', NULL, 'active', 4,
        N'{"capacidad":"10 Ton/hora","voltaje":"440V Trifásico","potencia_total":"35 kW","tecnologia_optica":"Cámaras InGaAs + RGB de alta velocidad"}',
        SYSUTCDATETIME()
    );

    -- Nivel 2: Sub-equipos de A005-001
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A005-001-01', N'Tolva y Alimentador Vibratorio', N'Syntron', N'MF-200',
        'A005', N'EST-CLAS-01', NULL,
        'subEquipment', N'A005-001', 'A005-001', 'active', 0,
        N'{"frecuencia_vibracion":"60 Hz","amplitud":"2.5 mm","capacidad_tolva":"500 L"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-02', N'Módulo Óptico y Sistema de Visión', N'Bühler', N'OptiCam HD-4',
        'A005', N'EST-CLAS-01', NULL,
        'subEquipment', N'A005-001', 'A005-001', 'active', 0,
        N'{"resolucion":"4096 px","iluminacion":"LED Polarizado","espectro":"Visible + Infrarrojo Cercano"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-03', N'Banda Transportadora de Clasificación', N'Habasit', N'HighSpeed-60',
        'A005', N'EST-CLAS-01', NULL,
        'subEquipment', N'A005-001', 'A005-001', 'active', 2,
        N'{"ancho_banda":"600 mm","velocidad_lineal":"3.5 m/s","material_banda":"Poliuretano Grado FDA"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-04', N'Sistema Expulsor Neumático', N'SMC / Bühler', N'AirJet-64',
        'A005', N'EST-CLAS-01', NULL,
        'subEquipment', N'A005-001', 'A005-001', 'active', 1,
        N'{"numero_eyectores":"64 toberas","tiempo_respuesta":"1.2 ms","presion_trabajo":"7.5 Bar"}',
        SYSUTCDATETIME()
    );

    -- Nivel 3: Partes (Hijos de Sub-equipos)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A005-001-03-01', N'Motorreductor Eléctrico de Arrastre', N'SEW-Eurodrive', N'K37 DRN80M4',
        'A005', N'EST-CLAS-01', NULL,
        'part', N'A005-001/A005-001-03', 'A005-001-03', 'active', 2,
        N'{"potencia":"1.1 kW / 1.5 HP","relacion_reduccion":"i=14.5","rpm_salida":"120 RPM","aceite_lubricante":"ISO VG 220 Sintético"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-03-02', N'Rodillo Tensor Autocentrante', N'Rulmeca', N'RT-600-PU',
        'A005', N'EST-CLAS-01', NULL,
        'part', N'A005-001/A005-001-03', 'A005-001-03', 'active', 0,
        N'{"diametro_tubo":"89 mm","eje":"25 mm","recubrimiento":"Goma vulcanizada 8mm"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-04-01', N'Manifold de Electroválvulas de Eyección', N'MAC Valves', N'Bullet Valve BV314',
        'A005', N'EST-CLAS-01', NULL,
        'part', N'A005-001/A005-001-04', 'A005-001-04', 'active', 1,
        N'{"voltaje_bobina":"24V DC","frecuencia_max":"500 Hz","vida_util_estimada":"100 Millones de ciclos"}',
        SYSUTCDATETIME()
    );

    -- Nivel 4: Sub-partes (Hijos de Partes)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A005-001-03-01-01', N'Rodamiento Frontal 6308-2RS C3', N'SKF / FAG', N'6308-2RS1/C3',
        'A005', N'EST-CLAS-01', NULL,
        'subPart', N'A005-001/A005-001-03/A005-001-03-01', 'A005-001-03-01', 'active', 0,
        N'{"diametro_interior":"40 mm","diametro_exterior":"90 mm","ancho":"23 mm","holgura":"C3 Radial"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-03-01-02', N'Retén de Aceite y Sello Viton 40x90x10', N'Freudenberg Simrit', N'BABSL 40-90-10 FKM',
        'A005', N'EST-CLAS-01', NULL,
        'subPart', N'A005-001/A005-001-03/A005-001-03-01', 'A005-001-03-01', 'active', 0,
        N'{"material_labio":"Viton FKM 80","presion_max":"0.5 Bar","temperatura_max":"200 °C"}',
        SYSUTCDATETIME()
    ),
    (
        'A005-001-04-01-01', N'Tobera Neumática de Alta Frecuencia 24V', N'MAC Valves', N'BV314A-CC1-00-BGA',
        'A005', N'EST-CLAS-01', NULL,
        'subPart', N'A005-001/A005-001-04/A005-001-04-01', 'A005-001-04-01', 'active', 0,
        N'{"tiempo_apertura":"0.8 ms","tiempo_cierre":"0.6 ms","consumo_potencia":"3.0 W"}',
        SYSUTCDATETIME()
    );

    -- ========================================================================
    -- 6. INSERTAR PLAN PREVENTIVO MAESTRO DE EJEMPLO
    -- ========================================================================
    PRINT N'📋 6. Creando Plan Preventivo de Demostración para A005-001...';

    DECLARE @PlanId NVARCHAR(60) = N'PM-A005-001-MENSUAL';
    DECLARE @FechaBase DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ProximaFecha DATETIME2(3) = DATEADD(day, 3, @FechaBase);

    INSERT INTO dbo.PlanPreventivo (
        PlanId, Titulo, CodigoActivo, NombreActivo, AreaId, NombreArea,
        TipoMantenimiento, Frecuencia, Descripcion, HorasEstimadas,
        FechaInicio, ProximaFecha, UltimaCompletada, UltimaOrdenTrabajoId,
        Estado, Notas, CreadoPorNombreUsuario, CreadoEn,
        IntervaloFrecuencia, UnidadFrecuencia
    ) VALUES (
        @PlanId, N'Mantenimiento Preventivo Mensual - Clasificadora Óptica',
        'A005-001', N'Máquina Clasificadora Óptica Industrial',
        'A005', N'CLASIFICADO',
        'preventive', 'monthly', N'Plan de inspección, calibración óptica y lubricación mensual', 4.0,
        @FechaBase, @ProximaFecha, NULL, NULL,
        'active', N'Plan maestro de mantenimiento preventivo', 'ADMIN', SYSUTCDATETIME(),
        1, N'meses'
    );

    -- Actividades vinculadas a componentes específicos
    INSERT INTO dbo.PlanPreventivoActividad (
        PlanId, CodigoActivoHijo, NombreActivoHijo, NivelActivoHijo,
        DescripcionActividad, ProcedimientoEstandar, IntervaloFrecuencia, UnidadFrecuencia,
        HorasEstimadas, FechaInicio, ProximaFecha, Estado, CreadoEn
    ) VALUES 
        (@PlanId, 'A005-001-02', N'Módulo Óptico y Sistema de Visión', 'subEquipment',
         N'Limpieza y calibración de lentes ópticos e iluminación LED', N'Utilizar toallitas ópticas con alcohol isopropílico al 99%.', 1, 'meses', 1.0, @FechaBase, @ProximaFecha, 'active', SYSUTCDATETIME()),
        
        (@PlanId, 'A005-001-03-01-01', N'Rodamiento Frontal 6308-2RS C3', 'subPart',
         N'Inspección de temperatura y vibración en rodamiento frontal SKF 6308', N'Medir con pirómetro láser y vibrómetro; máx 65°C.', 1, 'meses', 0.5, @FechaBase, @ProximaFecha, 'active', SYSUTCDATETIME()),
        
        (@PlanId, 'A005-001-03-01', N'Motorreductor Eléctrico de Arrastre', 'part',
         N'Verificación de nivel de aceite sintético ISO VG 220 en motorreductor SEW', N'Inspeccionar visor de nivel de aceite y rellenar si es necesario.', 1, 'meses', 0.5, @FechaBase, @ProximaFecha, 'active', SYSUTCDATETIME()),
        
        (@PlanId, 'A005-001-04-01-01', N'Tobera Neumática de Alta Frecuencia 24V', 'subPart',
         N'Prueba de estanqueidad y disparo neumático en toberas eyectoras MAC', N'Verificar ciclo de disparo a 7.5 Bar y ausencia de fugas de aire.', 1, 'meses', 1.0, @FechaBase, @ProximaFecha, 'active', SYSUTCDATETIME());

    -- ========================================================================
    -- 7. REGISTRO EN BITÁCORA KARDEX
    -- ========================================================================
    PRINT N'📜 7. Registrando eventos en Kardex de Auditoría...';

    INSERT INTO dbo.BitacoraKardex (
        Modulo, EntidadId, Accion, NombreUsuario, Detalles, RegistradoEn
    ) VALUES 
        ('AREAS', 'A003', 'AREA_CREATED', 'ADMIN', N'Creación de Área: EMPAQUE - MASTERIZADO (CC-39)', DATEADD(minute, -10, SYSUTCDATETIME())),
        ('AREAS', 'A005', 'AREA_CREATED', 'ADMIN', N'Creación de Área: CLASIFICADO (CC-41)', DATEADD(minute, -9, SYSUTCDATETIME())),
        ('ASSETS', 'A003-001', 'ASSET_CREATED', 'ADMIN', N'Alta de Activo Raíz: Línea Automática de Empaque y Masterizado con 4 niveles', DATEADD(minute, -8, SYSUTCDATETIME())),
        ('ASSETS', 'A005-001', 'ASSET_CREATED', 'ADMIN', N'Alta de Activo Raíz: Máquina Clasificadora Óptica Industrial con 4 niveles', DATEADD(minute, -7, SYSUTCDATETIME())),
        ('PREVENTIVE', @PlanId, 'PREVENTIVE_CREATED', 'ADMIN', N'Creación de Plan Preventivo Mensual para Clasificadora Óptica (A005-001)', DATEADD(minute, -5, SYSUTCDATETIME()));

    COMMIT TRANSACTION;

    PRINT N'============================================================================';
    PRINT N'🎉 BASE DE DATOS PREPARADA CON ÉXITO PARA LA PRESENTACIÓN EJECUTIVA';
    PRINT N'============================================================================';
    PRINT N'Áreas Creadas:       30 Áreas Oficiales (A001 a A030)';
    PRINT N'Activos Maestros:    A003-001 (Empaque) y A005-001 (Clasificado) con 4 niveles completos';
    PRINT N'Plan Preventivo:     PM-A005-001-MENSUAL con actividades por componente';
    PRINT N'Usuarios Demo:       ADMIN (Superadmin) y JEFE (Jefe Mantenimiento)';
    PRINT N'Contraseña Común:    ADMIN123';
    PRINT N'Contadores Reseteados: OTs arrancan en OT-2026-0001';
    PRINT N'============================================================================';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'❌ ERROR AL EJECUTAR SCRIPT:';
    PRINT ERROR_MESSAGE();
END CATCH;
GO
