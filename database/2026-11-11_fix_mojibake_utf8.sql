-- ============================================================================
-- SCRIPT DE REPARACIÓN: Limpieza de Mojibake UTF-8 / Windows-1252 en Tablas
-- Fecha: 2026-11-11
-- IMPORTANTE: Ejecutar siempre con sqlcmd -f 65001 -I
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

CREATE OR ALTER FUNCTION dbo.fnLimpiarMojibake (@Texto NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @Texto IS NULL RETURN NULL;

    DECLARE @Res NVARCHAR(MAX) = @Texto;

    -- IMPORTANTE: Aplicar COLLATE Latin1_General_BIN en cada REPLACE para
    -- coincidencia exacta por código Unicode (sin equivalencias CI/AS).
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(161)) COLLATE Latin1_General_BIN, N'á');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(169)) COLLATE Latin1_General_BIN, N'é');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(173)) COLLATE Latin1_General_BIN, N'í');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(179)) COLLATE Latin1_General_BIN, N'ó');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(186)) COLLATE Latin1_General_BIN, N'ú');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(177)) COLLATE Latin1_General_BIN, N'ñ');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(188)) COLLATE Latin1_General_BIN, N'ü');

    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(129))  COLLATE Latin1_General_BIN, N'Á');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(137))  COLLATE Latin1_General_BIN, N'É');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(8240)) COLLATE Latin1_General_BIN, N'É');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(141))  COLLATE Latin1_General_BIN, N'Í');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(147))  COLLATE Latin1_General_BIN, N'Ó');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(8220)) COLLATE Latin1_General_BIN, N'Ó');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(154))  COLLATE Latin1_General_BIN, N'Ú');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(353))  COLLATE Latin1_General_BIN, N'Ú');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(145))  COLLATE Latin1_General_BIN, N'Ñ');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(195) + NCHAR(8216)) COLLATE Latin1_General_BIN, N'Ñ');

    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(194) + NCHAR(191)) COLLATE Latin1_General_BIN, N'¿');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(194) + NCHAR(161)) COLLATE Latin1_General_BIN, N'¡');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(194) + NCHAR(176)) COLLATE Latin1_General_BIN, N'°');
    SET @Res = REPLACE(@Res COLLATE Latin1_General_BIN, (NCHAR(194) + NCHAR(183)) COLLATE Latin1_General_BIN, N'·');

    RETURN @Res COLLATE Modern_Spanish_CI_AS;
END;
GO

-- Restaurar nombres exactos de semilla de dbo.Empleado
UPDATE dbo.Empleado SET NombreCompleto = N'Ing. Nixon Mejía',        Puesto = N'Jefe de Mantenimiento'                      WHERE EmpleadoId = 1;
UPDATE dbo.Empleado SET NombreCompleto = N'Carlos Hernández',        Puesto = N'Técnico Mecánico Industrial'                WHERE EmpleadoId = 2;
UPDATE dbo.Empleado SET NombreCompleto = N'Jorge Morales',           Puesto = N'Técnico Electricista / Automatización'      WHERE EmpleadoId = 3;
UPDATE dbo.Empleado SET NombreCompleto = N'Roberto Rivas',           Puesto = N'Técnico Soldador / Estructuras'             WHERE EmpleadoId = 4;
UPDATE dbo.Empleado SET NombreCompleto = N'Miguel Ángel Castillo',   Puesto = N'Técnico Electromecánico'                    WHERE EmpleadoId = 5;
UPDATE dbo.Empleado SET NombreCompleto = N'Luis Alberto Fuentes',    Puesto = N'Técnico en Refrigeración y Calderas'        WHERE EmpleadoId = 6;
UPDATE dbo.Empleado SET NombreCompleto = N'Guillermo Pineda',        Puesto = N'Supervisor de Planta y Producción'          WHERE EmpleadoId = 7;
UPDATE dbo.Empleado SET NombreCompleto = N'Sandra Marroquín',        Puesto = N'Jefe de Aseguramiento de Calidad / HACCP'   WHERE EmpleadoId = 8;
GO

-- Restaurar nombres exactos de semilla de dbo.Puesto
UPDATE dbo.Puesto SET Nombre = N'Técnico Mecánico Industrial'             WHERE PuestoId = 1;
UPDATE dbo.Puesto SET Nombre = N'Técnico Electricista / Automatización'   WHERE PuestoId = 2;
UPDATE dbo.Puesto SET Nombre = N'Técnico Electromecánico'                 WHERE PuestoId = 3;
UPDATE dbo.Puesto SET Nombre = N'Técnico Soldador / Estructuras'          WHERE PuestoId = 4;
UPDATE dbo.Puesto SET Nombre = N'Técnico en Refrigeración y Calderas'     WHERE PuestoId = 5;
UPDATE dbo.Puesto SET Nombre = N'Jefe de Mantenimiento'                   WHERE PuestoId = 6;
UPDATE dbo.Puesto SET Nombre = N'Supervisor de Mantenimiento'             WHERE PuestoId = 7;
UPDATE dbo.Puesto SET Nombre = N'Supervisor de Planta y Producción'       WHERE PuestoId = 8;
UPDATE dbo.Puesto SET Nombre = N'Jefe de Aseguramiento de Calidad'        WHERE PuestoId = 9;
GO

-- Limpiar cualquier resto en otras tablas usando la función binaria exacta
UPDATE dbo.Rol
   SET Nombre = dbo.fnLimpiarMojibake(Nombre)
 WHERE Nombre COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.Usuario
   SET NombreCompleto = dbo.fnLimpiarMojibake(NombreCompleto)
 WHERE NombreCompleto COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.Area
   SET Nombre = dbo.fnLimpiarMojibake(Nombre)
 WHERE Nombre COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.Activo
   SET Nombre = dbo.fnLimpiarMojibake(Nombre),
       Marca  = dbo.fnLimpiarMojibake(Marca),
       Modelo = dbo.fnLimpiarMojibake(Modelo)
 WHERE Nombre COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR Marca  COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR Modelo COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.OrdenTrabajo
   SET NombreActivo                = dbo.fnLimpiarMojibake(NombreActivo),
       NombreArea                  = dbo.fnLimpiarMojibake(NombreArea),
       Descripcion                 = dbo.fnLimpiarMojibake(Descripcion),
       DescripcionTrabajoRealizado = dbo.fnLimpiarMojibake(DescripcionTrabajoRealizado)
 WHERE NombreActivo                COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR NombreArea                  COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR Descripcion                 COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR DescripcionTrabajoRealizado COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.ReporteAveria
   SET NombreActivo  = dbo.fnLimpiarMojibake(NombreActivo),
       Descripcion   = dbo.fnLimpiarMojibake(Descripcion),
       MotivoRechazo = dbo.fnLimpiarMojibake(MotivoRechazo)
 WHERE NombreActivo  COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR Descripcion   COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR MotivoRechazo COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

UPDATE dbo.PlanPreventivo
   SET Titulo            = dbo.fnLimpiarMojibake(Titulo),
       NombreActivo      = dbo.fnLimpiarMojibake(NombreActivo),
       NombreArea        = dbo.fnLimpiarMojibake(NombreArea),
       Descripcion       = dbo.fnLimpiarMojibake(Descripcion),
       TipoMantenimiento = dbo.fnLimpiarMojibake(TipoMantenimiento)
 WHERE Titulo            COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR NombreActivo      COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR NombreArea        COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR Descripcion       COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%'
    OR TipoMantenimiento COLLATE Latin1_General_BIN LIKE N'%[ÃÂ]%';
GO

PRINT 'Limpieza de mojibake UTF-8 completada con éxito.';
GO
