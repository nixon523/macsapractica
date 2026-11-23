const fs = require('fs');
const path = require('path');

// 1. Fix 04_activos_bajas_sp.sql
const p4 = path.resolve(__dirname, 'sql_modules/04_activos_bajas_sp.sql');
let code4 = fs.readFileSync(p4, 'utf8');

// Remove orphaned body
const orphanMarker = '-- Replaced uspActivoReactivar\n    SET NOCOUNT ON;';
const orphanEnd = 'END;\nGO\n\nCREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado';
const startIdx = code4.indexOf(orphanMarker);
const endIdx = code4.indexOf('CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado');

if (startIdx !== -1 && endIdx !== -1) {
  code4 = code4.substring(0, startIdx) + code4.substring(endIdx);
  console.log('Orphaned uspActivoReactivar body removed.');
}

// Fix uspActivoAlternarEstado parameters
code4 = code4.replace(
  `CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode NVARCHAR(60),`,
  `CREATE OR ALTER PROCEDURE dbo.uspActivoAlternarEstado
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,`
);

// Fix uspSolicitudBajaCrear parameters
code4 = code4.replace(
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode NVARCHAR(60),`,
  `CREATE OR ALTER PROCEDURE dbo.uspSolicitudBajaCrear
    @AssetCode    NVARCHAR(60) = NULL,
    @CodigoActivo NVARCHAR(60) = NULL,`
);

fs.writeFileSync(p4, code4, 'utf8');
console.log('04_activos_bajas_sp.sql fixed.');

// 2. Fix 05_averias_ots_preventivos_sp.sql
const p5 = path.resolve(__dirname, 'sql_modules/05_averias_ots_preventivos_sp.sql');
let code5 = fs.readFileSync(p5, 'utf8');

// Fix uspPlanPreventivoRegistrarEjecucion parameters
code5 = code5.replace(
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20) = NULL,
    @PlanId NVARCHAR(20) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''`,
  `CREATE OR ALTER PROCEDURE dbo.uspPlanPreventivoRegistrarEjecucion
    @ScheduleId NVARCHAR(20) = NULL,
    @PlanId NVARCHAR(20) = NULL,
    @WorkOrderId NVARCHAR(20) = NULL,
    @CompletedDate DATETIME2(3) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N''`
);

fs.writeFileSync(p5, code5, 'utf8');
console.log('05_averias_ots_preventivos_sp.sql fixed.');
