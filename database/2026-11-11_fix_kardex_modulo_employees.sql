-- ============================================================================
-- SCRIPT DE MIGRACIÓN: Ampliar CHECK Constraint CK_BK_Modulo para Empleados/Puestos
-- Fecha: 2026-11-11
-- ============================================================================

USE [MacsaCMMS];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF EXISTS (
    SELECT 1
      FROM sys.check_constraints
     WHERE name = N'CK_BK_Modulo'
       AND parent_object_id = OBJECT_ID(N'dbo.BitacoraKardex')
)
BEGIN
    ALTER TABLE dbo.BitacoraKardex DROP CONSTRAINT CK_BK_Modulo;
END;
GO

ALTER TABLE dbo.BitacoraKardex
ADD CONSTRAINT CK_BK_Modulo CHECK (
    Modulo IN (
        'ASSETS',
        'WORK_ORDERS',
        'BREAKDOWNS',
        'PREVENTIVE',
        'PREVENTIVE_SCHEDULES',
        'AREAS',
        'OPERATION_REPORTS',
        'USERS',
        'EMPLOYEES',
        'POSITIONS'
    )
);
GO

PRINT 'CK_BK_Modulo actualizado exitosamente para incluir EMPLOYEES y POSITIONS.';
GO

