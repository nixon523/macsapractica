-- ============================================================================
-- Migración: Actualización de Frecuencias Preventivas (Soporte Español / Inglés)
-- Base de datos: MacsaCMMS
-- ============================================================================

USE MacsaCMMS;
GO

-- 1. Actualizar el CHECK Constraint en dbo.PreventiveSchedule
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_PS_Frequency' AND parent_object_id = OBJECT_ID(N'dbo.PreventiveSchedule'))
BEGIN
    ALTER TABLE dbo.PreventiveSchedule DROP CONSTRAINT CK_PS_Frequency;
END;
GO

ALTER TABLE dbo.PreventiveSchedule ADD CONSTRAINT CK_PS_Frequency CHECK (Frequency IN (
    'daily','weekly','biweekly','monthly','bimonthly','quarterly','semiannual','annual',
    'Diaria','Semanal','Quincenal','Mensual','Bimestral','Trimestral','Semestral','Anual',
    'diaria','semanal','quincenal','mensual','bimestral','trimestral','semestral','anual'
));
GO

-- 2. Actualizar la función fnFrequencyDays
CREATE OR ALTER FUNCTION dbo.fnFrequencyDays (@Frequency NVARCHAR(15))
RETURNS INT
AS
BEGIN
    RETURN CASE LOWER(LTRIM(RTRIM(@Frequency)))
        WHEN 'daily'      THEN 1
        WHEN 'diaria'     THEN 1
        WHEN 'weekly'     THEN 7
        WHEN 'semanal'    THEN 7
        WHEN 'biweekly'   THEN 15
        WHEN 'quincenal'  THEN 15
        WHEN 'monthly'    THEN 30
        WHEN 'mensual'    THEN 30
        WHEN 'bimonthly'  THEN 60
        WHEN 'bimestral'  THEN 60
        WHEN 'quarterly'  THEN 90
        WHEN 'trimestral' THEN 90
        WHEN 'semiannual' THEN 180
        WHEN 'semestral'  THEN 180
        WHEN 'annual'     THEN 365
        WHEN 'anual'      THEN 365
        ELSE 30 END;
END;
GO

-- 3. Actualizar la función fnFrequencyLabel
CREATE OR ALTER FUNCTION dbo.fnFrequencyLabel (@Frequency NVARCHAR(15))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE LOWER(LTRIM(RTRIM(@Frequency)))
        WHEN 'daily'      THEN N'Diaria'
        WHEN 'diaria'     THEN N'Diaria'
        WHEN 'weekly'     THEN N'Semanal'
        WHEN 'semanal'    THEN N'Semanal'
        WHEN 'biweekly'   THEN N'Quincenal'
        WHEN 'quincenal'  THEN N'Quincenal'
        WHEN 'monthly'    THEN N'Mensual'
        WHEN 'mensual'    THEN N'Mensual'
        WHEN 'bimonthly'  THEN N'Bimestral'
        WHEN 'bimestral'  THEN N'Bimestral'
        WHEN 'quarterly'  THEN N'Trimestral'
        WHEN 'trimestral' THEN N'Trimestral'
        WHEN 'semiannual' THEN N'Semestral'
        WHEN 'semestral'  THEN N'Semestral'
        WHEN 'annual'     THEN N'Anual'
        WHEN 'anual'      THEN N'Anual'
        ELSE N'Mensual' END;
END;
GO

PRINT 'Migración de frecuencias preventivas aplicada correctamente.';
