-- ----------------------------------------------------------------------------
-- 13. PROCEDIMIENTOS ALMACENADOS: ÁREAS, PUESTOS Y EMPLEADOS
-- ----------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.uspAreaObtenerTodas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        AreaId,
        Nombre AS Name,
        CentroCosto AS CostCenter,
        ContadorActivos AS AssetCounter,
        Nombre,
        CentroCosto,
        ContadorActivos,
        Activo,
        CreadoEn,
        ActualizadoEn
      FROM dbo.Area
     WHERE Activo = 1
     ORDER BY AreaId ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaCrear
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50),
    @AreaId NVARCHAR(15) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NormCC NVARCHAR(50) =
            CASE WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter ELSE CONCAT('CC-', @CostCenter) END;

        DECLARE @FinalId NVARCHAR(15) = @AreaId;
        IF @FinalId IS NULL OR LTRIM(RTRIM(@FinalId)) = ''
        BEGIN
            DECLARE @cnt TABLE (val INT NOT NULL);
            UPDATE dbo.Contador WITH (UPDLOCK, HOLDLOCK)
               SET SiguienteNumero += 1
             OUTPUT inserted.SiguienteNumero INTO @cnt(val)
              WHERE Nombre = 'areas';

            DECLARE @nextVal INT; SELECT @nextVal = val FROM @cnt;
            SET @FinalId = CONCAT('A', FORMAT(@nextVal, '000'));
        END;

        IF EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @FinalId)
            RAISERROR(N'Ya existe un área con ese identificador.', 16, 1);

        INSERT INTO dbo.Area (AreaId, Nombre, CentroCosto, ContadorActivos, Activo, CreadoEn)
        VALUES (@FinalId, @Name, @NormCC, 0, 1, SYSUTCDATETIME());

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
    IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
    BEGIN
        SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
    END;
        IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID)
        BEGIN
            SELECT @UID = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N''))));
            IF @UID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UID) SET @UID = NULL;
        END;
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_CREATED', 'AREAS', @FinalId,
                CONCAT(N'Área creada: ', @FinalId, N' - ', @Name, N' (', @NormCC, N').'));

        COMMIT TRANSACTION;
        SELECT @FinalId AS AreaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaActualizar
    @AreaId NVARCHAR(15),
    @Name NVARCHAR(100),
    @CostCenter NVARCHAR(50) = NULL,
    @UserId INT = NULL,
    @UserName NVARCHAR(100) = N'',
    @UsuarioId INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NormCC NVARCHAR(50) =
        CASE WHEN @CostCenter IS NULL THEN NULL
             WHEN @CostCenter LIKE 'CC-%' THEN @CostCenter
             ELSE CONCAT('CC-', @CostCenter) END;

    UPDATE dbo.Area
       SET Nombre        = @Name,
           CentroCosto   = COALESCE(@NormCC, CentroCosto),
           ActualizadoEn = SYSUTCDATETIME()
     WHERE AreaId = @AreaId;

    IF @@ROWCOUNT = 0
        RAISERROR(N'El área especificada no existe.', 16, 1);

    DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
    DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
    INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
    VALUES (@UID, @UName, 'AREA_UPDATED', 'AREAS', @AreaId,
            CONCAT(N'Área actualizada: ', @AreaId, N' - ', @Name, N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspAreaEliminar
    @AreaId        NVARCHAR(15),
    @UserId        INT = NULL,
    @UserName      NVARCHAR(100) = N'',
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE AreaId = @AreaId)
            RAISERROR(N'El área especificada no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Activo WHERE AreaId = @AreaId AND Estado <> 'deleted')
            RAISERROR(N'No se puede eliminar el área porque contiene activos no eliminados.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE AreaId = @AreaId AND Activo = 1)
            RAISERROR(N'No se puede eliminar el área porque tiene empleados activos asignados.', 16, 1);

        UPDATE dbo.Area
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE AreaId = @AreaId;

        DECLARE @UID INT = COALESCE(@UserId, @UsuarioId);
        DECLARE @UName NVARCHAR(100) = COALESCE(NULLIF(@UserName, N''), @NombreUsuario, N'');
        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UID, @UName, 'AREA_DELETED', 'AREAS', @AreaId,
                CONCAT(N'Área dada de baja lógica: ', @AreaId, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoListar
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
      FROM dbo.Puesto
     WHERE (@SoloActivos = 0 OR Activo = 1)
     ORDER BY Nombre ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoCrear
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 1)
            RAISERROR(N'Ya existe un puesto registrado con ese mismo nombre.', 16, 1);

        DECLARE @ExistenteInactivoId INT;
        SELECT @ExistenteInactivoId = PuestoId FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND Activo = 0;

        DECLARE @NuevoId INT;
        IF @ExistenteInactivoId IS NOT NULL
        BEGIN
            UPDATE dbo.Puesto
               SET Activo = 1,
                   EsMantenimiento = @EsMantenimiento,
                   ActualizadoEn = SYSUTCDATETIME()
             WHERE PuestoId = @ExistenteInactivoId;
            SET @NuevoId = @ExistenteInactivoId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
            VALUES (@NombreLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
            SET @NuevoId = SCOPE_IDENTITY();
        END;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_CREATED', 'POSITIONS', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Puesto registrado: ', @NombreLimpio, N' (Mantenimiento: ', CASE WHEN @EsMantenimiento = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoActualizar
    @PuestoId        INT,
    @Nombre          NVARCHAR(100),
    @EsMantenimiento BIT = 1,
    @Activo          BIT = 1,
    @UsuarioId       INT = NULL,
    @NombreUsuario   NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE PuestoId = @PuestoId)
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        DECLARE @NombreLimpio NVARCHAR(100) = LTRIM(RTRIM(@Nombre));
        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre del puesto o cargo es obligatorio.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Puesto WHERE Nombre = @NombreLimpio AND PuestoId <> @PuestoId AND Activo = 1)
            RAISERROR(N'Ya existe otro puesto con ese mismo nombre.', 16, 1);

        UPDATE dbo.Puesto
           SET Nombre          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               Activo          = @Activo,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        UPDATE dbo.Empleado
           SET Puesto          = @NombreLimpio,
               EsMantenimiento = @EsMantenimiento,
               ActualizadoEn   = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_UPDATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto actualizado: ', @NombreLimpio, N' (Activo: ', CASE WHEN @Activo = 1 THEN N'Sí' ELSE N'No' END, N').'));

        COMMIT TRANSACTION;

        SELECT PuestoId, Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn
          FROM dbo.Puesto
         WHERE PuestoId = @PuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspPuestoEliminar
    @PuestoId      INT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreActual NVARCHAR(100);
        SELECT @NombreActual = Nombre FROM dbo.Puesto WHERE PuestoId = @PuestoId;

        IF @NombreActual IS NULL
            RAISERROR(N'El puesto o cargo no existe.', 16, 1);

        IF EXISTS (SELECT 1 FROM dbo.Empleado WHERE PuestoId = @PuestoId AND Activo = 1)
            RAISERROR(N'No se puede desactivar el puesto porque hay empleados activos que lo ocupan.', 16, 1);

        UPDATE dbo.Puesto
           SET Activo = 0,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE PuestoId = @PuestoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @NombreUsuario, 'POSITION_DEACTIVATED', 'POSITIONS', CAST(@PuestoId AS NVARCHAR(20)),
                CONCAT(N'Puesto desactivado: ', @NombreActual, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoListar
    @SoloActivos     BIT = 1,
    @EsMantenimiento BIT = NULL,
    @AreaId          NVARCHAR(15) = NULL,
    @Busqueda        NVARCHAR(100) = NULL,
    @Limit           INT = NULL,
    @Offset          INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.EmpleadoId,
        e.NombreCompleto,
        e.AreaId,
        COALESCE(a.Nombre, e.NombreArea, N'Sin Área Asignada') AS NombreArea,
        e.PuestoId,
        COALESCE(p.Nombre, e.Puesto) AS Puesto,
        COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
        e.Activo,
        e.CreadoEn,
        e.ActualizadoEn
    FROM dbo.Empleado e
    LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
    LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@EsMantenimiento IS NULL OR COALESCE(p.EsMantenimiento, e.EsMantenimiento) = @EsMantenimiento)
      AND (@AreaId IS NULL OR e.AreaId = @AreaId)
      AND (
          @Busqueda IS NULL
          OR LTRIM(RTRIM(@Busqueda)) = N''
          OR e.NombreCompleto LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
          OR COALESCE(p.Nombre, e.Puesto) LIKE CONCAT(N'%', LTRIM(RTRIM(@Busqueda)), N'%')
      )
    ORDER BY COALESCE(p.EsMantenimiento, e.EsMantenimiento) DESC, e.NombreCompleto ASC
    OFFSET @Offset ROWS
    FETCH NEXT CASE WHEN @Limit IS NULL OR @Limit <= 0 THEN 2147483647 ELSE @Limit END ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCrear
    @NombreCompleto   NVARCHAR(150),
    @AreaId           NVARCHAR(15) = NULL,
    @Puesto           NVARCHAR(100) = NULL,
    @PuestoId         INT = NULL,
    @EsMantenimiento  BIT = 1,
    @UsuarioId        INT = NULL,
    @NombreUsuario    NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreLimpio NVARCHAR(150) = LTRIM(RTRIM(ISNULL(@NombreCompleto, N'')));
        DECLARE @PuestoLimpio NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@Puesto, N'')));

        IF NULLIF(@NombreLimpio, N'') IS NULL
            RAISERROR(N'El nombre completo del empleado es obligatorio.', 16, 1);

        IF @PuestoId IS NOT NULL
        BEGIN
            SELECT @PuestoLimpio = Nombre,
                   @EsMantenimiento = EsMantenimiento
              FROM dbo.Puesto
             WHERE PuestoId = @PuestoId AND Activo = 1;

            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto especificado no existe o está inactivo.', 16, 1);
        END
        ELSE
        BEGIN
            IF NULLIF(@PuestoLimpio, N'') IS NULL
                RAISERROR(N'El puesto o cargo del empleado es obligatorio.', 16, 1);

            SELECT @PuestoId = PuestoId,
                   @PuestoLimpio = Nombre
              FROM dbo.Puesto
             WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);

            IF @PuestoId IS NULL
            BEGIN
                INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                SET @PuestoId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.Puesto
                   SET Activo = 1, ActualizadoEn = SYSUTCDATETIME()
                 WHERE PuestoId = @PuestoId AND Activo = 0;
            END;
        END;

        DECLARE @NombreArea NVARCHAR(200) = NULL;
        IF @AreaId IS NOT NULL
        BEGIN
            SELECT @NombreArea = Nombre FROM dbo.Area WHERE AreaId = @AreaId;
        END;

        INSERT INTO dbo.Empleado (NombreCompleto, AreaId, NombreArea, PuestoId, Puesto, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
        VALUES (@NombreLimpio, @AreaId, @NombreArea, @PuestoId, @PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());

        DECLARE @NuevoId INT = SCOPE_IDENTITY();

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_CREATED', 'EMPLOYEES', CAST(@NuevoId AS NVARCHAR(20)),
                CONCAT(N'Empleado registrado: ', @NombreLimpio, N' (Puesto: ', @PuestoLimpio, N').'));

        COMMIT TRANSACTION;

        SELECT
            e.EmpleadoId,
            e.NombreCompleto,
            e.AreaId,
            COALESCE(a.Nombre, e.NombreArea, N'Sin Área') AS NombreArea,
            e.PuestoId,
            COALESCE(p.Nombre, e.Puesto) AS Puesto,
            COALESCE(p.EsMantenimiento, e.EsMantenimiento) AS EsMantenimiento,
            e.Activo,
            e.CreadoEn,
            e.ActualizadoEn
        FROM dbo.Empleado e
        LEFT JOIN dbo.Puesto p ON e.PuestoId = p.PuestoId
        LEFT JOIN dbo.Area a ON e.AreaId = a.AreaId
        WHERE e.EmpleadoId = @NuevoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoActualizar
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
                IF NOT EXISTS (SELECT 1 FROM dbo.Puesto WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio))
                BEGIN
                    INSERT INTO dbo.Puesto (Nombre, EsMantenimiento, Activo, CreadoEn, ActualizadoEn)
                    VALUES (@PuestoLimpio, @EsMantenimiento, 1, SYSUTCDATETIME(), SYSUTCDATETIME());
                    SET @PuestoId = SCOPE_IDENTITY();
                END
                ELSE
                BEGIN
                    SELECT TOP 1 @PuestoId = PuestoId, @PuestoLimpio = Nombre
                      FROM dbo.Puesto
                     WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(@PuestoLimpio);
                END;
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

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_UPDATED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
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

CREATE OR ALTER PROCEDURE dbo.uspEmpleadoCambiarEstado
    @EmpleadoId    INT,
    @Activo        BIT,
    @UsuarioId     INT = NULL,
    @NombreUsuario NVARCHAR(100) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Empleado
           SET Activo = @Activo,
               ActualizadoEn = SYSUTCDATETIME()
         WHERE EmpleadoId = @EmpleadoId;

        IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId)
        BEGIN
            SELECT @UsuarioId = UsuarioId FROM dbo.Usuario WHERE UPPER(NombreUsuario) = UPPER(LTRIM(RTRIM(@NombreUsuario)));
            IF @UsuarioId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioId) SET @UsuarioId = NULL;
        END;

        DECLARE @UNameAudit NVARCHAR(100) = COALESCE(NULLIF(LTRIM(RTRIM(@NombreUsuario)), N''), N'SISTEMA');

        INSERT INTO dbo.BitacoraKardex (UsuarioId, NombreUsuario, Accion, Modulo, EntidadId, Detalles)
        VALUES (@UsuarioId, @UNameAudit, 'EMPLOYEE_STATUS_CHANGED', 'EMPLOYEES', CAST(@EmpleadoId AS NVARCHAR(20)),
                CONCAT(N'Estado de empleado ID ', @EmpleadoId, N' cambiado a: ', CASE WHEN @Activo = 1 THEN N'Activo' ELSE N'Inactivo' END, N'.'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
