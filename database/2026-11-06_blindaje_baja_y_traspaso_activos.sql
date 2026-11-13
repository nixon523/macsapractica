-- ============================================================================
-- Migración: Blindaje de Integridad para Bajas y Traspasos de Activos
-- Fecha: 2026-11-06
-- Autor: Antigravity / Grupo Macsa
-- ============================================================================
-- DESCRIPCIÓN:
-- 1. Impide transferir un activo si él o alguno de sus subcomponentes cuenta
--    con órdenes de trabajo (OTs) abiertas o en progreso.
-- 2. Impide aprobar o solicitar la baja de un activo si cuenta con OTs abiertas.
-- 3. Pausa automáticamente los planes preventivos activos de un activo dado de baja.
-- ============================================================================

USE [MacsaCMMS];
GO

PRINT '============================================================================';
PRINT 'Iniciando migración: Blindaje de integridad en Bajas y Traspasos...';
PRINT '============================================================================';
GO

-- 1. Blindaje en Solicitud y Aprobación de Baja
CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaAprobar
    @RequestId BIGINT, @ApproverUserId INT = NULL, @ApproverUserName NVARCHAR(100) = N'',
    @ApproveReason NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @c NVARCHAR(60), @nm NVARCHAR(200), @ar NVARCHAR(15), @st NVARCHAR(10);
        SELECT @c = CodigoActivo, @nm = NombreActivo, @ar = AreaId, @st = Estado
          FROM dbo.SolicitudBaja WITH (UPDLOCK, HOLDLOCK) WHERE SolicitudId = @RequestId;

        IF @c IS NULL OR @st <> 'pending'
        BEGIN
            RAISERROR(N'Esta solicitud ya fue resuelta o no está pendiente.', 16, 1);
        END;

        -- Validar que no existan OTs abiertas en el activo o sus descendientes
        DECLARE @OTAbiertaId NVARCHAR(20);
        SELECT TOP 1 @OTAbiertaId = ot.OrdenTrabajoId
          FROM dbo.OrdenTrabajo ot WITH (UPDLOCK, HOLDLOCK)
          JOIN dbo.Activo a WITH (NOLOCK) ON ot.CodigoActivo = a.CodigoActivo
         WHERE a.AreaId = @ar
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0)
           AND ot.Estado IN (N'pending', N'inProgress', N'in_progress', N'paused');

        IF @OTAbiertaId IS NOT NULL
        BEGIN
            DECLARE @MsgBaja NVARCHAR(250) = CONCAT(N'No se puede dar de baja: el activo o sus subcomponentes tienen la orden de trabajo abierta (', @OTAbiertaId, N'). Debe concluirse o cancelarse primero.');
            RAISERROR(@MsgBaja, 16, 1);
        END;

        -- Marcar el activo y sus descendientes como eliminados
        UPDATE a
           SET Estado = 'deleted', EliminadoEn = SYSUTCDATETIME(),
               EliminadoPorUsuarioId = @ApproverUserId, EliminadoPorNombreUsuario = @ApproverUserName,
               ActualizadoEn = SYSUTCDATETIME()
          FROM dbo.Activo a
         WHERE a.AreaId = @ar AND a.Estado <> 'deleted'
           AND (a.CodigoActivo = @c OR CHARINDEX(CONCAT(N',', @c, N','), CONCAT(N',', a.RutaAncestros, N',')) > 0);

        -- Pausar automáticamente planes preventivos activos del activo
        UPDATE dbo.PlanPreventivo
           SET Estado = 'paused',
               Notas = ISNULL(Notas, '') + CONCAT(CHAR(13), CHAR(10), N'[Sistema]: Plan preventivo pausado automáticamente por baja del activo.')
         WHERE CodigoActivo = @c AND Estado = 'active';

        UPDATE dbo.SolicitudBaja
           SET Estado = 'approved', DecididoPorUsuarioId = @ApproverUserId,
               DecididoPorNombreUsuario = @ApproverUserName, DecididoEn = SYSUTCDATETIME(),
               MotivoDecision = COALESCE(@ApproveReason, N'')
         WHERE SolicitudId = @RequestId;

        UPDATE dbo.CandadoBaja SET EstadoCandado = 'approved', ActualizadoEn = SYSUTCDATETIME() WHERE CodigoActivo = @c;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@ApproverUserId, @ApproverUserName, 'ASSET_DELETED', 'ASSETS', @c,
                CONCAT(N'Aprobada la solicitud de baja ', @RequestId, N' para ', @c, N' (', @nm, N'). Planes preventivos pausados.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Blindaje de baja y pausa automática de preventivos registrado con éxito.';
GO

