/* ============================================================================
   MACSA CMMS - Grupo Macsa
   seed_activo_clasificado_jerarquia.sql
   Registro Completo de Activo con Jerarquía de 4 Niveles para el Área de Clasificado

   Estructura Jerárquica:
   ├── A4-001 (Equipo)                               : Máquina Clasificadora Óptica Industrial
   │   ├── A4-001-01 (Sub-equipo)                    : Tolva y Alimentador Vibratorio
   │   ├── A4-001-02 (Sub-equipo)                    : Módulo Óptico y Sistema de Visión
   │   ├── A4-001-03 (Sub-equipo)                    : Banda Transportadora de Clasificación
   │   │   ├── A4-001-03-01 (Parte)                  : Motorreductor Eléctrico de Arrastre
   │   │   │   ├── A4-001-03-01-01 (Sub-parte)       : Rodamiento Frontal 6308-2RS
   │   │   │   └── A4-001-03-01-02 (Sub-parte)       : Retén de Aceite y Sello Viton
   │   │   └── A4-001-03-02 (Parte)                  : Rodillo Tensor Autocentrante
   │   └── A4-001-04 (Sub-equipo)                    : Sistema Expulsor Neumático
   │       └── A4-001-04-01 (Parte)                  : Manifold de Electroválvulas de Eyección
   │           └── A4-001-04-01-01 (Sub-parte)       : Tobera Neumática de Alta Frecuencia 24V
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @AreaId NVARCHAR(15) = N'A4';
    DECLARE @NombreArea NVARCHAR(100) = N'Área de Clasificado';
    DECLARE @CentroCosto NVARCHAR(50) = N'CC-CLAS-04';

    -- 1. Asegurar que exista el Área de Clasificado (A4)
    IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaId)
    BEGIN
        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, CreadoEn)
        VALUES (@AreaId, @NombreArea, @CentroCosto, 1, SYSUTCDATETIME());
        PRINT CONCAT('Área ', @AreaId, ' (', @NombreArea, ') creada.');
    END
    ELSE
    BEGIN
        UPDATE dbo.Area 
           SET Nombre = @NombreArea, CentroCosto = @CentroCosto 
         WHERE AreaId = @AreaId;
    END;

    -- 2. Limpieza segura de pruebas anteriores sobre este código de equipo
    DECLARE @Codigos TABLE (Codigo NVARCHAR(60));
    INSERT INTO @Codigos VALUES 
        ('A4-001-04-01-01'), ('A4-001-04-01'), ('A4-001-04'),
        ('A4-001-03-01-02'), ('A4-001-03-01-01'), ('A4-001-03-01'), ('A4-001-03-02'), ('A4-001-03'),
        ('A4-001-02'), ('A4-001-01'), ('A4-001');

    DELETE ppa FROM dbo.PlanPreventivoActividad ppa WHERE CodigoActivoHijo IN (SELECT Codigo FROM @Codigos);
    DELETE pp FROM dbo.PlanPreventivo pp WHERE CodigoActivo = 'A4-001';
    DELETE hea FROM dbo.HistorialEstadoActivo hea WHERE CodigoActivo IN (SELECT Codigo FROM @Codigos);
    DELETE a FROM dbo.Activo a WHERE CodigoActivo IN (SELECT Codigo FROM @Codigos);

    -- ========================================================================
    -- 3. INSERTAR JERARQUÍA (4 NIVELES)
    -- ========================================================================

    -- ── NIVEL 1: EQUIPO RAÍZ (Padre Principal) ──────────────────────────────
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES (
        'A4-001', N'Máquina Clasificadora Óptica Industrial', N'Bühler Sortex', N'Sortex S-Ultra 400', 
        @AreaId, N'EST-CLAS-01', N'SN-CLAS-2026-001',
        'equipment', N'', NULL, 'active', 4,
        N'{"capacidad":"10 Ton/hora","voltaje":"440V Trifásico","potencia_total":"35 kW","tecnologia_optica":"Cámaras InGaAs + RGB"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 2: SUB-EQUIPOS (Hijos de A4-001) ─────────────────────────────
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A4-001-01', N'Tolva y Alimentador Vibratorio', N'Syntron', N'MF-200',
        @AreaId, N'EST-CLAS-01', NULL,
        'subEquipment', N'A4-001', 'A4-001', 'active', 0,
        N'{"frecuencia_vibracion":"60 Hz","amplitud":"2.5 mm","capacidad_tolva":"500 L"}',
        SYSUTCDATETIME()
    ),
    (
        'A4-001-02', N'Módulo Óptico y Sistema de Visión', N'Bühler', N'OptiCam HD-4',
        @AreaId, N'EST-CLAS-01', NULL,
        'subEquipment', N'A4-001', 'A4-001', 'active', 0,
        N'{"resolucion":"4096 px","iluminacion":"LED Polarizado","espectro":"Visible + Infrarrojo Cercano"}',
        SYSUTCDATETIME()
    ),
    (
        'A4-001-03', N'Banda Transportadora de Clasificación', N'Habasit', N'HighSpeed-60',
        @AreaId, N'EST-CLAS-01', NULL,
        'subEquipment', N'A4-001', 'A4-001', 'active', 2,
        N'{"longitud":"4.5 m","ancho_banda":"800 mm","velocidad_max":"4.2 m/s"}',
        SYSUTCDATETIME()
    ),
    (
        'A4-001-04', N'Sistema Expulsor Neumático', N'Festo', N'HighSpeed-ValveBank',
        @AreaId, N'EST-CLAS-01', NULL,
        'subEquipment', N'A4-001', 'A4-001', 'active', 1,
        N'{"presion_trabajo":"6.5 bar","tiempo_respuesta":"2 ms","cantidad_toberas":"128"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 3: PARTES ────────────────────────────────────────────────────
    -- Hijos de la Banda (A4-001-03)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A4-001-03-01', N'Motorreductor Eléctrico de Arrastre', N'SEW Eurodrive', N'KAF67 DRN100L4',
        @AreaId, N'EST-CLAS-01', NULL,
        'part', N'A4-001,A4-001-03', 'A4-001-03', 'active', 2,
        N'{"potencia":"3.0 kW","relacion_reduccion":"1:14.2","rpm_salida":"125 RPM"}',
        SYSUTCDATETIME()
    ),
    (
        'A4-001-03-02', N'Rodillo Tensor Autocentrante', N'Rulmeca', N'RT-800-HD',
        @AreaId, N'EST-CLAS-01', NULL,
        'part', N'A4-001,A4-001-03', 'A4-001-03', 'active', 0,
        N'{"diametro":"160 mm","recubrimiento":"Goma vulcanizada 60 Shore A"}',
        SYSUTCDATETIME()
    );

    -- Hijos del Expulsor Neumático (A4-001-04)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A4-001-04-01', N'Manifold de Electroválvulas de Eyección', N'SMC', N'VQ1000-HighFreq',
        @AreaId, N'EST-CLAS-01', NULL,
        'part', N'A4-001,A4-001-04', 'A4-001-04', 'active', 1,
        N'{"caudal_nominal":"450 L/min","voltaje_bobina":"24V DC"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 4: SUB-PARTES ────────────────────────────────────────────────
    -- Hijos del Motorreductor (A4-001-03-01)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A4-001-03-01-01', N'Rodamiento Frontal 6308-2RS C3', N'SKF', N'6308-2RS/C3',
        @AreaId, N'EST-CLAS-01', NULL,
        'subPart', N'A4-001,A4-001-03,A4-001-03-01', 'A4-001-03-01', 'active', 0,
        N'{"dimensiones":"40x90x23 mm","holgura":"C3","sellado":"Doble labio NBR"}',
        SYSUTCDATETIME()
    ),
    (
        'A4-001-03-01-02', N'Retén de Aceite y Sello Viton', N'Freudenberg', N'BA-40-62-7',
        @AreaId, N'EST-CLAS-01', NULL,
        'subPart', N'A4-001,A4-001-03,A4-001-03-01', 'A4-001-03-01', 'active', 0,
        N'{"material":"FKM Viton","temperatura_max":"200 °C"}',
        SYSUTCDATETIME()
    );

    -- Hijos del Manifold (A4-001-04-01)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A4-001-04-01-01', N'Tobera Neumática de Alta Frecuencia 24V', N'SMC', N'SV-NOZ-01',
        @AreaId, N'EST-CLAS-01', NULL,
        'subPart', N'A4-001,A4-001-04,A4-001-04-01', 'A4-001-04-01', 'active', 0,
        N'{"orificio_salida":"1.2 mm","ciclos_vida":"100 Millones de disparos"}',
        SYSUTCDATETIME()
    );

    -- 4. Registrar Historial de Estados Inicial
    INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, NombreUsuario)
    SELECT a.CodigoActivo, a.Estado, SYSUTCDATETIME(), a.AreaId, N'Alta de activo de prueba para Área de Clasificado', N'admin'
      FROM dbo.Activo a
     WHERE a.CodigoActivo LIKE 'A4-001%';

    -- 5. Registrar en la Bitácora Kardex
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    SELECT 
        1, N'admin', 'ASSET_CREATED', 'ASSETS', a.CodigoActivo,
        CONCAT(N'Creación del activo [', a.Nivel, N']: ', a.CodigoActivo, N' - ', a.Nombre)
      FROM dbo.Activo a
     WHERE a.CodigoActivo LIKE 'A4-001%';

    -- 6. Actualizar Contador de Activos en el Área
    UPDATE dbo.Area 
       SET ContadorActivos = (SELECT COUNT(*) FROM dbo.Activo WHERE AreaId = @AreaId AND Nivel = 'equipment')
     WHERE AreaId = @AreaId;

    COMMIT TRANSACTION;

    PRINT N'========================================================================';
    PRINT N'¡Activo y Jerarquía Completa para Área de Clasificado Creados con Éxito!';
    PRINT N'========================================================================';

    -- 7. Consultar y mostrar el árbol jerárquico creado
    SELECT 
        REPLICATE('    ', CASE a.Nivel 
            WHEN 'equipment' THEN 0 
            WHEN 'subEquipment' THEN 1 
            WHEN 'part' THEN 2 
            WHEN 'subPart' THEN 3 END) + 
        CONCAT('├── [', a.Nivel, '] ', a.CodigoActivo, ' - ', a.Nombre) AS EstructuraJerarquica,
        a.Marca,
        a.Modelo,
        a.Serie,
        a.Estado
    FROM dbo.Activo a
    WHERE a.CodigoActivo LIKE 'A4-001%'
    ORDER BY a.CodigoActivo;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error al registrar el activo jerárquico:';
    THROW;
END CATCH
GO
