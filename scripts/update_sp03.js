const fs = require('fs');
const path = require('path');

const targetPath = path.resolve(__dirname, 'sql_modules/03_areas_puestos_empleados_sp.sql');
let code = fs.readFileSync(targetPath, 'utf8');

// Replace uspEmpleadoActualizar
const startIdx = code.indexOf('CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar');
const endIdx = code.indexOf('CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCambiarEstado');

if (startIdx !== -1 && endIdx !== -1) {
  const newProc = `CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
    @EmpleadoId       INT,
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @Activo           BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId)
            RAISERROR(N'El empleado no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT TOP 1 @PuestoId = PuestoId,
                         @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio)
                OR Nombre = @PuestoLimpio;

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        UPDATE dbo.Empleado
           SET NombreCompleto  = @NombreLimpio,
               AreaId          = @AreaId,
               NombreArea      = @NombreArea,
               PuestoId        = @PuestoId,
               Puesto          = @PuestoLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        -- Validar UsuarioId para auditoría
        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
                SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Empleado actualizado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N', Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            e.EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @EmpleadoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

`;
  code = code.substring(0, startIdx) + newProc + code.substring(endIdx);
  fs.writeFileSync(targetPath, code, 'utf8');
  console.log('Successfully updated uspEmpleadoActualizar in', targetPath);
} else {
  console.error('Could not find start or end index for uspEmpleadoActualizar');
}
