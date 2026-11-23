const fs = require('fs');

// 1. Fix 05_averias_ots_preventivos_sp.sql
let f5 = fs.readFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', 'utf8');

// Replace uspPlanPreventivoModificar and ensure uspPlanPreventivoRegistrarEjecucion exists
const modIdx = f5.indexOf('CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoModificar');
const altIdx = f5.indexOf('CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoAlternarEstado');

if (modIdx !== -1 && altIdx !== -1) {
  const replacement = `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoModificar
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @Title               NVARCHAR(200) = NULL,
    @MaintenanceType     NVARCHAR(100) = NULL,
    @Frequency           NVARCHAR(20) = NULL,
    @Description         NVARCHAR(MAX) = NULL,
    @EstimatedHours      DECIMAL(6,2) = NULL,
    @StartDate           DATETIME2(3) = NULL,
    @NextDate            DATETIME2(3) = NULL,
    @Notes               NVARCHAR(500) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @ModifiedDocNumber   NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @AmendmentReason     NVARCHAR(500) = NULL,
    @ModifyReason        NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N'',
    @Materials           dbo.TipoMaterialPreventivo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlan NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);

        UPDATE dbo.PlanPreventivo
           SET Titulo                      = COALESCE(@Title, Titulo),
               TipoMantenimiento           = COALESCE(@MaintenanceType, TipoMantenimiento),
               Frecuencia                  = COALESCE(@Frequency, Frecuencia),
               Descripcion                 = COALESCE(@Description, Descripcion),
               HorasEstimadas              = COALESCE(@EstimatedHours, HorasEstimadas),
               FechaInicio                 = COALESCE(@StartDate, FechaInicio),
               ProximaFecha                = COALESCE(@NextDate, ProximaFecha),
               Notas                       = COALESCE(@Notes, Notas),
               NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, @ModifiedDocNumber, NumeroDocumentoModificacion),
               ModificadoPor               = COALESCE(@UserName, ModificadoPor),
               ModificadoEn                = SYSUTCDATETIME(),
               MotivoModificacion          = COALESCE(@AmendmentReason, @ModifyReason, MotivoModificacion)
         WHERE PlanId = @TargetPlan;

        IF EXISTS (SELECT 1 FROM @Materials)
        BEGIN
            DELETE FROM dbo.MaterialPreventivo WHERE PlanId = @TargetPlan;
            INSERT INTO dbo.MaterialPreventivo (PlanId, NumeroLinea, Nombre, Cantidad, Unidad)
            SELECT @TargetPlan, ROW_NUMBER() OVER (ORDER BY LineNum), Name, Quantity, ISNULL(Unit, 'pza')
            FROM @Materials;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_MODIFIED', 'PREVENTIVE', @TargetPlan,
                CONCAT(N'Plan preventivo ', @TargetPlan, N' modificado. Motivo: ', ISNULL(COALESCE(@AmendmentReason, @ModifyReason), N'N/A')));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20) = NULL,
    @PlanId NVARCHAR(20) = NULL,
    @WorkOrderId NVARCHAR(20),
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlanExec NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);

        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = SYSUTCDATETIME(),
               UltimaOrdenTrabajoId = @WorkOrderId
         WHERE PlanId = @TargetPlanExec;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_EXECUTED', 'PREVENTIVE', @TargetPlanExec,
                CONCAT(N'Ejecución del plan preventivo ', @TargetPlanExec, N' registrada con OT ', @WorkOrderId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

`;
  f5 = f5.substring(0, modIdx) + replacement + f5.substring(altIdx);
}
fs.writeFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', f5, 'utf8');

// 2. Fix 06_operacion_analitica_kardex_sp.sql
let f6 = fs.readFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', 'utf8');

const opRegIdx = f6.indexOf('CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar');
const opSemIdx = f6.indexOf('CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana');

if (opRegIdx !== -1 && opSemIdx !== -1) {
  const replacement = `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionRegistrar
    @CodigoActivo         NVARCHAR(60),
    @FechaOperacion       DATE,
    @HorasTotalesJornada  DECIMAL(5,2) = 24.0,
    @HorasOperacion       DECIMAL(5,2) = 0.0,
    @HorasParoFalla       DECIMAL(5,2) = 0.0,
    @HorasParoMantPrev    DECIMAL(5,2) = 0.0,
    @HorasParoMantCorr    DECIMAL(5,2) = 0.0,
    @HorasParoPlanificado DECIMAL(5,2) = 0.0,
    @HorasParoExterno     DECIMAL(5,2) = 0.0,
    @HorasParoOtros       DECIMAL(5,2) = 0.0,
    @Comentarios          NVARCHAR(500) = NULL,
    @Observaciones        NVARCHAR(500) = NULL,
    @UsuarioId            INT = NULL,
    @NombreUsuario        NVARCHAR(100) = N'',
    @RegistradoPorUsuarioId INT = NULL,
    @RegistradoPorNombreUsuario NVARCHAR(100) = N'',
    @UnidadesProducidas   DECIMAL(12,2) = NULL,
    @UnidadesEsperadas    DECIMAL(12,2) = NULL,
    @UnidadesConformes    DECIMAL(12,2) = NULL,
    @RendimientoDirectoPct DECIMAL(5,2) = NULL,
    @CalidadDirectoPct    DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AreaId NVARCHAR(15);
        SELECT @AreaId = AreaId FROM dbo.Activo WHERE CodigoActivo = @CodigoActivo;

        DECLARE @Obs NVARCHAR(500) = COALESCE(@Observaciones, @Comentarios);
        DECLARE @UID INT = COALESCE(@RegistradoPorUsuarioId, @UsuarioId);
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@RegistradoPorNombreUsuario, N''), @NombreUsuario, N'');

        IF EXISTS (SELECT 1 FROM dbo.ReporteOperacionDiaria WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion)
        BEGIN
            UPDATE dbo.ReporteOperacionDiaria
               SET HorasTotalesJornada        = @HorasTotalesJornada,
                   HorasOperacion             = @HorasOperacion,
                   HorasParoFalla             = @HorasParoFalla,
                   HorasParoMantPrev          = @HorasParoMantPrev,
                   HorasParoMantCorr          = @HorasParoMantCorr,
                   HorasParoPlanificado       = @HorasParoPlanificado,
                   HorasParoExterno           = @HorasParoExterno,
                   Observaciones              = @Obs,
                   RegistradoPorUsuarioId     = @UID,
                   RegistradoPorNombreUsuario = @UName,
                   ActualizadoEn              = SYSUTCDATETIME()
             WHERE CodigoActivo = @CodigoActivo AND FechaOperacion = @FechaOperacion;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.ReporteOperacionDiaria
                (CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada, HorasOperacion,
                 HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr, HorasParoPlanificado,
                 HorasParoExterno, Observaciones, RegistradoPorUsuarioId, RegistradoPorNombreUsuario)
            VALUES
                (@CodigoActivo, @AreaId, @FechaOperacion, @HorasTotalesJornada, @HorasOperacion,
                 @HorasParoFalla, @HorasParoMantPrev, @HorasParoMantCorr, @HorasParoPlanificado,
                 @HorasParoExterno, @Obs, @UID, @UName);
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorActivo
    @CodigoActivo       NVARCHAR(60),
    @FechaDesde         DATE = NULL,
    @FechaHasta         DATE = NULL,
    @FechaInicio        DATE = NULL,
    @FechaFin           DATE = NULL,
    @Pagina             INT = 1,
    @RegistrosPorPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Offset INT = CASE WHEN @Pagina > 1 THEN (@Pagina - 1) * @RegistrosPorPagina ELSE 0 END;

    SELECT ReporteId, CodigoActivo, AreaId, FechaOperacion, HorasTotalesJornada,
           HorasOperacion, HorasParoFalla, HorasParoMantPrev, HorasParoMantCorr,
           HorasParoPlanificado, HorasParoExterno, Observaciones,
           RegistradoPorUsuarioId, RegistradoPorNombreUsuario, RegistradoEn, ActualizadoEn
      FROM dbo.ReporteOperacionDiaria
     WHERE CodigoActivo = @CodigoActivo
       AND FechaOperacion BETWEEN @Inicio AND @Fin
     ORDER BY FechaOperacion DESC
     OFFSET @Offset ROWS
     FETCH NEXT @RegistrosPorPagina ROWS ONLY;
END;
GO

`;
  f6 = f6.substring(0, opRegIdx) + replacement + f6.substring(opSemIdx);
}
fs.writeFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', f6, 'utf8');

console.log('Procedimientos sincronizados exitosamente.');
