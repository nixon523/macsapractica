/* ============================================================================
   MACSA CMMS - Creación de Activo de Ejemplo con Jerarquía Completa (4 Niveles)
   database/seed_activos_ejemplo.sql

   Estructura que se creará en el Área A1 (Línea de Producción 1):
   ├── A1-003 (Equipo)                   : Generador Diésel Principal
   │   └── A1-003-01 (Sub-equipo)        : Motor de Combustión Interna
   │       └── A1-003-01-01 (Parte)      : Bomba de Inyección de Combustible
   │           └── A1-003-01-01-01 (Sub-parte) : Inyector Electrónico #1
   ============================================================================ */

USE MacsaCMMS;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- 1. Asegurar que existe el Área A1
    IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = 'A1')
    BEGIN
        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos)
        VALUES ('A1', N'Línea de Producción 1', 'CC-101', 3);
    END;

    -- 2. Limpiar registros previos si ya existían para evitar colisiones
    DELETE FROM dbo.HistorialEstadoActivo WHERE CodigoActivo IN ('A1-003-01-01-01', 'A1-003-01-01', 'A1-003-01', 'A1-003');
    DELETE FROM dbo.Activo WHERE CodigoActivo IN ('A1-003-01-01-01', 'A1-003-01-01', 'A1-003-01', 'A1-003');

    -- 3. Insertar la Jerarquía de 4 Niveles
    -- Nivel 1: Equipo Raíz
    INSERT INTO dbo.Activo
        (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
         Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
         AtributosDinamicos, CreadoEn)
    VALUES
        ('A1-003', N'Generador Diésel Principal', N'Caterpillar', N'CAT C15', 'A1', 'S1', 'GEN-2026-X1',
         'equipment', '', NULL, 'active', 1,
         N'{"potencia":"500 kVA","combustible":"Diesel","voltaje":"480V"}', SYSUTCDATETIME());

    -- Nivel 2: Sub-equipo
    INSERT INTO dbo.Activo
        (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
         Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
         AtributosDinamicos, CreadoEn)
    VALUES
        ('A1-003-01', N'Motor de Combustión Interna', N'Caterpillar', N'C15 ACERT', 'A1', 'S1', NULL,
         'subEquipment', 'A1-003', 'A1-003', 'active', 1,
         N'{"cilindrada":"15.2 L","cilindros":"6 en linea","rpm":"1800"}', SYSUTCDATETIME());

    -- Nivel 3: Parte
    INSERT INTO dbo.Activo
        (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
         Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
         AtributosDinamicos, CreadoEn)
    VALUES
        ('A1-003-01-01', N'Bomba de Inyección de Combustible', N'Bosch', N'CP4.2', 'A1', 'S1', NULL,
         'part', 'A1-003,A1-003-01', 'A1-003-01', 'active', 1,
         N'{"presion_max":"2000 bar","tipo":"Common Rail"}', SYSUTCDATETIME());

    -- Nivel 4: Sub-parte
    INSERT INTO dbo.Activo
        (CodigoActivo, Nombre, Marca, Modelo, AreaId, EstacionId, Serie,
         Nivel, RutaAncestros, CodigoActivoPadre, Estado, ContadorHijos,
         AtributosDinamicos, CreadoEn)
    VALUES
        ('A1-003-01-01-01', N'Inyector Electrónico #1', N'Bosch', N'CRI3-20', 'A1', 'S1', NULL,
         'subPart', 'A1-003,A1-003-01,A1-003-01-01', 'A1-003-01-01', 'active', 0,
         N'{"orificios":"8","tobera":"Micro-sac"}', SYSUTCDATETIME());

    -- 4. Registrar el Historial de Estado inicial para cada activo
    INSERT INTO dbo.HistorialEstadoActivo (CodigoActivo, Estado, IniciadoEn, AreaId, Motivo, NombreUsuario)
    VALUES
        ('A1-003',             'active', SYSUTCDATETIME(), 'A1', N'Alta inicial del equipo', 'ADMIN'),
        ('A1-003-01',          'active', SYSUTCDATETIME(), 'A1', N'Alta inicial del sub-equipo', 'ADMIN'),
        ('A1-003-01-01',       'active', SYSUTCDATETIME(), 'A1', N'Alta inicial de parte', 'ADMIN'),
        ('A1-003-01-01-01',    'active', SYSUTCDATETIME(), 'A1', N'Alta inicial de sub-parte', 'ADMIN');

    -- 5. Registrar en la Bitácora Kardex
    INSERT INTO dbo.BitacoraKardex (EntidadId, Modulo, Accion, Detalle, NombreUsuario, RegistradoEn)
    VALUES
        ('A1-003',          'ASSETS', 'ASSET_CREATED', N'Creación del equipo Generador Diésel Principal (A1-003)', 'ADMIN', SYSUTCDATETIME()),
        ('A1-003-01',       'ASSETS', 'ASSET_CREATED', N'Creación del sub-equipo Motor de Combustión Interna (A1-003-01)', 'ADMIN', SYSUTCDATETIME()),
        ('A1-003-01-01',    'ASSETS', 'ASSET_CREATED', N'Creación de parte Bomba de Inyección (A1-003-01-01)', 'ADMIN', SYSUTCDATETIME()),
        ('A1-003-01-01-01', 'ASSETS', 'ASSET_CREATED', N'Creación de sub-parte Inyector Electrónico #1 (A1-003-01-01-01)', 'ADMIN', SYSUTCDATETIME());

    -- 6. Actualizar el contador de activos del área A1
    UPDATE dbo.Area SET ContadorActivos = 3 WHERE AreaId = 'A1' AND ContadorActivos < 3;

    COMMIT TRANSACTION;

    -- Mostrar los registros creados
    SELECT CodigoActivo, Nombre, Nivel, CodigoActivoPadre, RutaAncestros, Serie, Estado
      FROM dbo.Activo
     WHERE CodigoActivo LIKE 'A1-003%'
     ORDER BY CodigoActivo;

    PRINT N'¡Jerarquía de 4 niveles creada con éxito en el Área A1!';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'Error al crear la jerarquía de activos:';
    THROW;
END CATCH;
GO
