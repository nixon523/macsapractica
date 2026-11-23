const fs = require('fs');
const path = require('path');

// 1. Update 01_tables.sql to include PlanPreventivoId and ActualizadoEn in dbo.OrdenTrabajo
let f1 = fs.readFileSync('scripts/sql_modules/01_tables.sql', 'utf8');
if (!f1.includes('PlanPreventivoId              NVARCHAR(20)')) {
  f1 = f1.replace(
    /CreadoPorNombreUsuario\s+NVARCHAR\(100\)\s+NULL,/i,
    `CreadoPorNombreUsuario      NVARCHAR(100) NULL,
    PlanPreventivoId            NVARCHAR(20)  NULL,
    ActualizadoEn               DATETIME2(3)  NULL,`
  );
  fs.writeFileSync('scripts/sql_modules/01_tables.sql', f1, 'utf8');
  console.log('01_tables.sql actualizado.');
}

// 2. Fix 04_activos_bajas_sp.sql (uspActivoActualizar)
let f4 = fs.readFileSync('scripts/sql_modules/04_activos_bajas_sp.sql', 'utf8');
f4 = f4.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspActivoActualizar\s*\n\s*@AssetCode/i,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoActualizar
    @CodigoActivo NVARCHAR(60) = NULL,
    @AssetCode`
);
f4 = f4.replace(
  /WHERE CodigoActivo = COALESCE\(@CodigoActivo, @AssetCode\);/g,
  `WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);`
);
f4 = f4.replace(
  /WHERE CodigoActivo = @AssetCode;/g,
  `WHERE CodigoActivo = COALESCE(@AssetCode, @CodigoActivo);`
);
fs.writeFileSync('scripts/sql_modules/04_activos_bajas_sp.sql', f4, 'utf8');
console.log('04_activos_bajas_sp.sql actualizado.');

// 3. Fix 05_averias_ots_preventivos_sp.sql
let f5 = fs.readFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', 'utf8');

// Fix uspReporteAveriaRechazar
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteAveriaRechazar[\s\S]*?AS\s+BEGIN[\s\S]*?UPDATE dbo\.ReporteAveria[\s\S]*?WHERE ReporteId = @ReportId;[\s\S]*?VALUES \(@RejectedByUserId[\s\S]*?COMMIT TRANSACTION;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteAveriaRechazar
    @ReportId BIGINT,
    @Reason NVARCHAR(500) = NULL,
    @RejectReason NVARCHAR(500) = NULL,
    @RejectedByUserId INT = NULL,
    @RejectedByUserName NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MotivoRechazo NVARCHAR(500) = COALESCE(@Reason, @RejectReason, N'');

        UPDATE dbo.ReporteAveria
           SET Estado = 'rejected',
                MotivoRechazo = @MotivoRechazo,
                RechazadoPorUsuarioId = @RejectedByUserId,
                RechazadoPorNombreUsuario = @RejectedByUserName,
                RechazadoEn = SYSUTCDATETIME()
          WHERE ReporteId = @ReportId;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@RejectedByUserId, @RejectedByUserName, 'BREAKDOWN_REJECTED', 'BREAKDOWNS', CAST(@ReportId AS NVARCHAR(20)),
                CONCAT(N'Reporte de avería ', @ReportId, N' rechazado. Motivo: ', @MotivoRechazo));

        COMMIT TRANSACTION;`
);

// Fix uspPlanPreventivoModificar (Materials column names in TipoMaterialPreventivo: NumeroLinea, Nombre, Cantidad, Unidad)
f5 = f5.replace(
  /SELECT @TargetPlan, ROW_NUMBER\(\) OVER \(ORDER BY LineNum\), Name, Quantity, ISNULL\(Unit, 'pza'\)\s+FROM @Materials;/i,
  `SELECT @TargetPlan, ROW_NUMBER() OVER (ORDER BY NumeroLinea), Nombre, Cantidad, ISNULL(Unidad, 'pza') FROM @Materials;`
);

// Fix uspPlanPreventivoAlternarEstado
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoAlternarEstado[\s\S]*?AS\s+BEGIN[\s\S]*?INSERT INTO dbo\.BitacoraKardex[\s\S]*?VALUES \(@UserId, @UserName, 'PREVENTIVE_PLAN_STATUS'[\s\S]*?END;\s*GO/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoAlternarEstado
    @ScheduleId          NVARCHAR(20) = NULL,
    @PlanId              NVARCHAR(20) = NULL,
    @NewStatus           NVARCHAR(15) = NULL,
    @NuevoEstado         NVARCHAR(15) = NULL,
    @AmendmentDocNumber  NVARCHAR(50) = NULL,
    @AuthorizedByManager BIT = 0,
    @Reason              NVARCHAR(500) = NULL,
    @Motivo              NVARCHAR(500) = NULL,
    @UserId              INT = NULL,
    @UserName            NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TargetPlanAlt NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
    DECLARE @TargetStatusAlt NVARCHAR(15) = COALESCE(@NewStatus, @NuevoEstado);

    UPDATE dbo.PlanPreventivo
       SET Estado = @TargetStatusAlt,
           NumeroDocumentoModificacion = COALESCE(@AmendmentDocNumber, NumeroDocumentoModificacion),
           MotivoModificacion = COALESCE(@Reason, @Motivo, MotivoModificacion),
           ModificadoPor = COALESCE(@UserName, ModificadoPor),
           ModificadoEn = SYSUTCDATETIME()
     WHERE PlanId = @TargetPlanAlt;

    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_STATUS', 'PREVENTIVE', @TargetPlanAlt,
            CONCAT(N'Estado de plan preventivo ', @TargetPlanAlt, N' cambiado a: ', @TargetStatusAlt, N'.'));
END;
GO`
);

// Fix uspPlanPreventivoRegistrarEjecucion
f5 = f5.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspPlanPreventivoRegistrarEjecucion[\s\S]*?AS\s+BEGIN[\s\S]*?INSERT INTO dbo\.BitacoraKardex[\s\S]*?VALUES \(@UserId, @UserName, 'PREVENTIVE_PLAN_EXECUTED'[\s\S]*?END;\s*GO/i,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId   NVARCHAR(20) = NULL,
    @PlanId       NVARCHAR(20) = NULL,
    @WorkOrderId  NVARCHAR(20),
    @CompletedDate DATETIME2(3) = NULL,
    @UserId       INT = NULL,
    @UserName     NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TargetPlanExec NVARCHAR(20) = COALESCE(@ScheduleId, @PlanId);
        DECLARE @DateFinal DATETIME2(3) = COALESCE(@CompletedDate, SYSUTCDATETIME());

        UPDATE dbo.PlanPreventivo
           SET UltimaCompletada = @DateFinal,
               UltimaOrdenTrabajoId = @WorkOrderId
         WHERE PlanId = @TargetPlanExec;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UserId, @UserName, 'PREVENTIVE_PLAN_EXECUTED', 'PREVENTIVE', @TargetPlanExec,
                CONCAT(N'Ejecución del plan preventivo ', @TargetPlanExec, N' registrada con OT ', @WorkOrderId, N'. Fecha: ', CONVERT(NVARCHAR(30), @DateFinal, 120)));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO`
);

fs.writeFileSync('scripts/sql_modules/05_averias_ots_preventivos_sp.sql', f5, 'utf8');
console.log('05_averias_ots_preventivos_sp.sql actualizado.');

// 4. Fix 06_operacion_analitica_kardex_sp.sql
let f6 = fs.readFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', 'utf8');

// Fix duplicate WHERE in uspKardexObtenerPorEntidad
f6 = f6.replace(
  /END;\s*WHERE EntidadId = @EntityId\s*ORDER BY RegistradoEn DESC;\s*END;/i,
  `END;`
);

// Fix uspReporteOperacionObtenerPorSemana
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionObtenerPorSemana[\s\S]*?AS\s+BEGIN[\s\S]*?ORDER BY r\.FechaOperacion DESC, r\.CodigoActivo ASC;\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionObtenerPorSemana
    @AreaId          NVARCHAR(15),
    @LunesDeLaSemana DATE = NULL,
    @FechaInicio     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BaseDate DATE = COALESCE(@LunesDeLaSemana, @FechaInicio, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @Lunes DATE = DATEADD(DAY, - (DATEPART(WEEKDAY, @BaseDate) + 5) % 7, @BaseDate);
    DECLARE @Domingo DATE = DATEADD(DAY, 6, @Lunes);

    SELECT r.ReporteId, r.CodigoActivo, a.Nombre AS NombreActivo, r.AreaId, ar.Nombre AS NombreArea,
           r.FechaOperacion, r.HorasTotalesJornada, r.HorasOperacion, r.HorasParoFalla,
           r.HorasParoMantPrev, r.HorasParoMantCorr, r.HorasParoPlanificado, r.HorasParoExterno,
           r.Observaciones, r.RegistradoPorNombreUsuario, r.RegistradoEn
      FROM dbo.ReporteOperacionDiaria r
      JOIN dbo.Activo a ON r.CodigoActivo = a.CodigoActivo
      JOIN dbo.Area ar ON r.AreaId = ar.AreaId
     WHERE (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Lunes AND @Domingo
     ORDER BY r.FechaOperacion DESC, r.CodigoActivo ASC;
END;`
);

// Fix uspReporteOperacionMetricas
f6 = f6.replace(
  /CREATE OR ALTER PROCEDURE dbo\.uspReporteOperacionMetricas[\s\S]*?AS\s+BEGIN[\s\S]*?FROM dbo\.ReporteOperacionDiaria r[\s\S]*?ORDER BY [^;]*?;?\s*END;/i,
  `CREATE OR ALTER PROCEDURE dbo.uspReporteOperacionMetricas
    @CodigoActivo NVARCHAR(60) = NULL,
    @AreaId       NVARCHAR(15) = NULL,
    @FechaDesde   DATE = NULL,
    @FechaHasta   DATE = NULL,
    @FechaInicio  DATE = NULL,
    @FechaFin     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATE = COALESCE(@FechaDesde, @FechaInicio, DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE)));
    DECLARE @Fin DATE = COALESCE(@FechaHasta, @FechaFin, CAST(SYSUTCDATETIME() AS DATE));

    SELECT
        COUNT(DISTINCT r.CodigoActivo) AS TotalEquiposMonitoreados,
        SUM(r.HorasTotalesJornada)     AS TotalHorasJornada,
        SUM(r.HorasOperacion)          AS TotalHorasOperacion,
        SUM(r.HorasParoFalla)          AS TotalHorasParoFalla,
        SUM(r.HorasParoMantPrev)       AS TotalHorasParoPreventivo,
        SUM(r.HorasParoMantCorr)       AS TotalHorasParoCorrectivo,
        SUM(r.HorasParoPlanificado)    AS TotalHorasParoPlanificado,
        SUM(r.HorasParoExterno)        AS TotalHorasParoExterno,
        CASE WHEN SUM(r.HorasTotalesJornada) > 0
             THEN ROUND((SUM(r.HorasOperacion) / SUM(r.HorasTotalesJornada)) * 100.0, 2)
             ELSE 0.00 END AS PorcentajeDisponibilidadGlobal
      FROM dbo.ReporteOperacionDiaria r
     WHERE (@CodigoActivo IS NULL OR r.CodigoActivo = @CodigoActivo)
       AND (@AreaId IS NULL OR r.AreaId = @AreaId)
       AND r.FechaOperacion BETWEEN @Inicio AND @Fin;
END;`
);

fs.writeFileSync('scripts/sql_modules/06_operacion_analitica_kardex_sp.sql', f6, 'utf8');
console.log('06_operacion_analitica_kardex_sp.sql actualizado.');
