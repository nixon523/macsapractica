/* ============================================================================
   MACSA CMMS - Grupo Macsa
   seed_activo_empaque_masterizado.sql
   Registro Completo de Activo con Jerarquía de 4 Niveles para el Área:
   A003 - EMPAQUE - MASTERIZADO (Centro de Costos: CC-39)

   Estructura Jerárquica:
   ├── A003-001 (Equipo)                             : Línea Automática de Empaque y Masterizado
   │   ├── A003-001-01 (Sub-equipo)                  : Formadora Automática de Cajas Master
   │   ├── A003-001-02 (Sub-equipo)                  : Envasadora Vertical Multicabezal
   │   ├── A003-001-03 (Sub-equipo)                  : Robot Encartonador Pick & Place
   │   │   ├── A003-001-03-01 (Parte)                : Módulo de Garra de Succión por Vacío
   │   │   │   ├── A003-001-03-01-01 (Sub-parte)     : Ventosa de Succión Grado Alimentario Ø50mm
   │   │   │   └── A003-001-03-01-02 (Sub-parte)     : Generador de Vacío Eyector Venturi
   │   │   └── A003-001-03-02 (Parte)                : Servomotor de Eje Principal Z
   │   └── A003-001-04 (Sub-equipo)                  : Precintadora y Selladora Hot Melt
   │       └── A003-001-04-01 (Parte)                : Unidad Aplicadora de Adhesivo Termofusible
   │           └── A003-001-04-01-01 (Sub-parte)     : Boquilla Dosificadora Neumática Hot Melt 0.4mm
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @AreaId NVARCHAR(15) = N'A003';
    DECLARE @NombreArea NVARCHAR(100) = N'EMPAQUE - MASTERIZADO';
    DECLARE @CentroCosto NVARCHAR(50) = N'CC-39';

    -- 1. Asegurar o actualizar el Área A003
    IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaId)
    BEGIN
        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, CreadoEn)
        VALUES (@AreaId, @NombreArea, @CentroCosto, 1, SYSUTCDATETIME());
        PRINT CONCAT('Área ', @AreaId, ' (', @NombreArea, ') creada.');
    END
    ELSE
    BEGIN
        UPDATE dbo.Area 
           SET Nombre = @NombreArea, 
               CentroCosto = @CentroCosto,
               ContadorActivos = CASE WHEN ContadorActivos < 1 THEN 1 ELSE ContadorActivos END
         WHERE AreaId = @AreaId;
    END;

    -- 2. Limpieza de registros previos con este código para evitar conflictos
    DECLARE @Codigos TABLE (Codigo NVARCHAR(60) COLLATE database_default);
    INSERT INTO @Codigos VALUES 
        ('A003-001-04-01-01'), ('A003-001-04-01'), ('A003-001-04'),
        ('A003-001-03-01-02'), ('A003-001-03-01-01'), ('A003-001-03-01'), ('A003-001-03-02'), ('A003-001-03'),
        ('A003-001-02'), ('A003-001-01'), ('A003-001');

    DELETE ppa FROM dbo.PlanPreventivoActividad ppa WHERE CodigoActivoHijo IN (SELECT Codigo FROM @Codigos);
    DELETE pp FROM dbo.PlanPreventivo pp WHERE CodigoActivo = 'A003-001';
    DELETE hea FROM dbo.HistorialEstadoActivo hea WHERE CodigoActivo IN (SELECT Codigo FROM @Codigos);
    DELETE a FROM dbo.Activo a WHERE CodigoActivo IN (SELECT Codigo FROM @Codigos);

    -- ========================================================================
    -- 3. INSERTAR JERARQUÍA COMPLETA (4 NIVELES)
    -- ========================================================================

    -- ── NIVEL 1: EQUIPO RAÍZ (Padre Principal) ──────────────────────────────
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES (
        'A003-001', N'Línea Automática de Empaque y Masterizado', N'Meypack / Ishida', N'VP-Master 600', 
        @AreaId, N'EST-EMP-01', N'SN-EMP-2026-001',
        'equipment', N'', NULL, 'active', 4,
        N'{"capacidad":"45 cajas/min","voltaje":"440V Trifásico","potencia_total":"28 kW","presion_aire":"6.0 bar","tipo_empaque":"Caja Corrugada Master"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 2: SUB-EQUIPOS (Hijos de A003-001) ────────────────────────────
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-01', N'Formadora Automática de Cajas Master (Case Erector)', N'Lantech', N'C-1000',
        @AreaId, N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 0,
        N'{"velocidad_armado":"30 cajas/min","dimension_max_caja":"600x400x400 mm","almacen_planchas":"150 unidades"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-02', N'Envasadora Vertical Multicabezal', N'Ishida', N'CCW-R2-214W',
        @AreaId, N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 0,
        N'{"cabezales_pesaje":"14","precision":"±0.5 g","rango_pesaje":"50g - 2500g"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03', N'Robot Encartonador Pick & Place', N'Fanuc Robotics', N'M-710iC/50',
        @AreaId, N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 2,
        N'{"carga_util":"50 kg","alcance_brazo":"2050 mm","grados_libertad":"6 ejes"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-04', N'Precintadora y Selladora Hot Melt', N'Nordson / 3M', N'ProBlue 7',
        @AreaId, N'EST-EMP-01', NULL,
        'subEquipment', N'A003-001', 'A003-001', 'active', 1,
        N'{"temperatura_aplicacion":"175 °C","capacidad_tanque":"7.0 L","tipo_adhesivo":"EVA / Metallocene"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 3: PARTES ─────────────────────────────────────────────────────
    -- Hijos del Robot Encartonador (A003-001-03)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-03-01', N'Módulo de Garra de Succión por Vacío', N'Schmalz', N'SPZ-M-50',
        @AreaId, N'EST-EMP-01', NULL,
        'part', N'A003-001,A003-001-03', 'A003-001-03', 'active', 2,
        N'{"fuerza_retencion":"450 N","numero_ventosas":"12","material_placa":"Aluminio Anodizado"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03-02', N'Servomotor de Eje Principal Z', N'Fanuc', N'Alpha iS 22/4000',
        @AreaId, N'EST-EMP-01', NULL,
        'part', N'A003-001,A003-001-03', 'A003-001-03', 'active', 0,
        N'{"potencia":"4.5 kW","torque_nominal":"22 Nm","rpm_max":"4000 RPM"}',
        SYSUTCDATETIME()
    );

    -- Hijos de la Selladora Hot Melt (A003-001-04)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-04-01', N'Unidad Aplicadora de Adhesivo Termofusible', N'Nordson', N'SolidBlue S',
        @AreaId, N'EST-EMP-01', NULL,
        'part', N'A003-001,A003-001-04', 'A003-001-04', 'active', 1,
        N'{"presion_hidraulica_max":"100 bar","voltaje_calefactor":"230V","frecuencia_disparo":"4000 ciclos/min"}',
        SYSUTCDATETIME()
    );

    -- ── NIVEL 4: SUB-PARTES ─────────────────────────────────────────────────
    -- Hijos de la Garra de Succión (A003-001-03-01)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-03-01-01', N'Ventosa de Succión Grado Alimentario Ø50mm', N'Schmalz', N'SAB-50-SI-55',
        @AreaId, N'EST-EMP-01', NULL,
        'subPart', N'A003-001,A003-001-03,A003-001-03-01', 'A003-001-03-01', 'active', 0,
        N'{"diametro":"50 mm","material":"Silicona FDA","fuelle":"1.5 pliegues"}',
        SYSUTCDATETIME()
    ),
    (
        'A003-001-03-01-02', N'Generador de Vacío Eyector Venturi', N'Festo', N'VN-07-L-T3-PQ2',
        @AreaId, N'EST-EMP-01', NULL,
        'subPart', N'A003-001,A003-001-03,A003-001-03-01', 'A003-001-03-01', 'active', 0,
        N'{"vacio_max":"-85 kPa","caudal_aspiracion":"38.5 L/min","tobera":"0.7 mm"}',
        SYSUTCDATETIME()
    );

    -- Hijos de la Unidad Aplicadora Hot Melt (A003-001-04-01)
    INSERT INTO dbo.Activo (
        CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
        Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
        AtributosDinamicos, CreadoEn
    ) VALUES 
    (
        'A003-001-04-01-01', N'Boquilla Dosificadora Neumática Hot Melt 0.4mm', N'Nordson', N'Saturn-0.4-Single',
        @AreaId, N'EST-EMP-01', NULL,
        'subPart', N'A003-001,A003-001-04,A003-001-04-01', 'A003-001-04-01', 'active', 0,
        N'{"orificio_salida":"0.4 mm","material":"Carburo de Tungsteno","patron_aplicacion":"Cordon continuo"}',
        SYSUTCDATETIME()
    );

    -- 4. Registrar Historial de Estados Inicial
    INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, NombreUsuario)
    SELECT a.CodigoActivo, a.Estado, SYSUTCDATETIME(), a.AreaId, N'Alta de equipo de empaque y masterizado', N'admin'
      FROM dbo.Activo a
     WHERE a.CodigoActivo LIKE 'A003-001%';

    -- 5. Registrar en la Bitácora Kardex inmutable
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    SELECT 
        1, N'admin', 'ASSET_CREATED', 'ASSETS', a.CodigoActivo,
        CONCAT(N'Creación del activo [', a.Nivel, N']: ', a.CodigoActivo, N' - ', a.Nombre)
      FROM dbo.Activo a
     WHERE a.CodigoActivo LIKE 'A003-001%';

    -- 6. Actualizar Contador de Activos en el Área A003
    UPDATE dbo.Area 
       SET ContadorActivos = (SELECT COUNT(*) FROM dbo.Activo WHERE AreaId = @AreaId AND Nivel = 'equipment')
     WHERE AreaId = @AreaId;

    COMMIT TRANSACTION;

    PRINT N'========================================================================';
    PRINT N'¡Activo y Jerarquía Completa para Área A003 Creados con Éxito!';
    PRINT N'========================================================================';

    -- 7. Mostrar la estructura jerárquica generada
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
    WHERE a.CodigoActivo LIKE 'A003-001%'
    ORDER BY a.CodigoActivo;

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error al registrar el activo jerárquico para A003:';
    THROW;
END CATCH
GO
