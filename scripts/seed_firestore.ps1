$ErrorActionPreference = 'Stop'
$key = "AIzaSyDAZ319nPKpK2MBe5do0U-WmAPBRtFE1AQ"
$base = "https://firestore.googleapis.com/v1/projects/practica-macsa/databases/(default)/documents"

function Set-FsDoc {
    param(
        [string]$Path,
        [hashtable]$Fields
    )
    $body = @{ fields = $Fields } | ConvertTo-Json -Depth 20 -Compress
    $uri = "$base/${Path}?key=$key"
    try {
        Invoke-RestMethod -Uri $uri -Method PATCH -ContentType "application/json" -Body $body | Out-Null
        Write-Host "OK  $Path"
    } catch {
        $r = $_.Exception.Response
        $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
        $detail = $sr.ReadToEnd()
        Write-Host "FAIL $Path :: $detail"
        Write-Host "BODY: $body"
        throw
    }
}

# Helpers para construir campos Firestore
function FStr([string]$v) { return @{ stringValue = $v } }
function FInt([int]$v) { return @{ integerValue = "$v" } }
function FArrStr([string[]]$v) { return @{ arrayValue = @{ values = @($v | ForEach-Object { @{ stringValue = $_ } }) } } }
function FMap([hashtable]$v) {
    $fields = @{}
    foreach ($k in $v.Keys) { $fields[$k] = $v[$k] }
    return @{ mapValue = @{ fields = $fields } }
}
function FNull() { return @{ nullValue = $null } }
function FBool([bool]$v) { return @{ booleanValue = $v } }

# ================= 1. USUARIOS (RBAC por roles) =================
# Contraseñas almacenadas con PBKDF2-HMAC-SHA256 (salt + hash), nunca en
# texto plano. El hash se genera con la MISMA implementación que usa la app
# (lib/core/security/password_hasher.dart) vía el helper de CLI.
function Get-PasswordHash([string]$Password) {
    $json = & dart run tool/hash_password.dart "$Password"
    if ($LASTEXITCODE -ne 0) { throw "Error al generar el hash de la contraseña." }
    return $json | ConvertFrom-Json
}

function FTime([DateTime]$dt) {
    return @{ timestampValue = $dt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
}

# admin (Gestor del Sistema): acceso total por el rol (hasPermission=true).
$adminCreds = Get-PasswordHash "1234"
Set-FsDoc -Path "users/admin" -Fields @{
    username            = FStr "admin"
    displayName         = FStr "Administrador General"
    role                = FStr "admin"
    passwordSalt        = FStr $adminCreds.salt
    passwordHash        = FStr $adminCreds.hash
    passwordIterations  = FInt $($adminCreds.iterations)
    permissions         = FArrStr @("dashboard.view", "asset.view", "asset.create", "asset.edit", "asset.transfer", "asset.delete.request", "asset.delete.approve", "work_order.view", "work_order.create", "preventive.view", "kardex.view", "breakdown.report", "breakdown.view", "user.manage")
    disabled            = FNull
}

# lector (Solo Lectura): solo información, sin acciones.
$lectorCreds = Get-PasswordHash "1234"
Set-FsDoc -Path "users/lector" -Fields @{
    username            = FStr "lector"
    displayName         = FStr "Lector de Información"
    role                = FStr "lector"
    passwordSalt        = FStr $lectorCreds.salt
    passwordHash        = FStr $lectorCreds.hash
    passwordIterations  = FInt $($lectorCreds.iterations)
    permissions         = FArrStr @("dashboard.view", "asset.view", "work_order.view", "preventive.view", "kardex.view", "breakdown.view")
    disabled            = FNull
}

# reportador (Reportador de Averías): reporta y ve sus propios reportes.
$reportadorCreds = Get-PasswordHash "1234"
Set-FsDoc -Path "users/reportador" -Fields @{
    username            = FStr "reportador"
    displayName         = FStr "Reportador de Averías"
    role                = FStr "reportador"
    passwordSalt        = FStr $reportadorCreds.salt
    passwordHash        = FStr $reportadorCreds.hash
    passwordIterations  = FInt $($reportadorCreds.iterations)
    permissions         = FArrStr @("asset.view", "breakdown.report")
    disabled            = FNull
}

# jefe y gerente: cuentas legadas DESHABILITADAS (no pueden iniciar sesión).
$jefeCreds = Get-PasswordHash "1234"
Set-FsDoc -Path "users/jefe" -Fields @{
    username            = FStr "jefe"
    displayName         = FStr "Jefe de Área (legado)"
    role                = FStr "lector"
    passwordSalt        = FStr $jefeCreds.salt
    passwordHash        = FStr $jefeCreds.hash
    passwordIterations  = FInt $($jefeCreds.iterations)
    permissions         = FArrStr @()
    disabled            = FBool $true
}
$gerenteCreds = Get-PasswordHash "1234"
Set-FsDoc -Path "users/gerente" -Fields @{
    username            = FStr "gerente"
    displayName         = FStr "Gerente de Operaciones (legado)"
    role                = FStr "lector"
    passwordSalt        = FStr $gerenteCreds.salt
    passwordHash        = FStr $gerenteCreds.hash
    passwordIterations  = FInt $($gerenteCreds.iterations)
    permissions         = FArrStr @()
    disabled            = FBool $true
}

# ================= 1b. CONTADOR DE ÓRDENES DE TRABAJO =================
# nextNumber = 2  => la próxima OT será OT-0002 (OT-0001 ya sembrada).
Set-FsDoc -Path "counters/work_orders" -Fields @{
    nextNumber = FInt 2
}

# ================= 2. CONTADOR GLOBAL DE ÁREAS =================
# nextNumber = 4  => la próxima área creada será A4 (A1..A3 ya sembradas)
Set-FsDoc -Path "counters/areas" -Fields @{
    nextNumber = FInt 4
}

# ================= 3. ÁREAS =================
# assetCounter: siguiente número de equipo del área (A1 ya tiene 2 equipos => 2)
Set-FsDoc -Path "areas/A1" -Fields @{
    id           = FStr "A1"
    name         = FStr "Planta de Procesamiento"
    costCenter   = FStr "CC-01"
    assetCounter = FInt 2
}
Set-FsDoc -Path "areas/A2" -Fields @{
    id           = FStr "A2"
    name         = FStr "Empacadora"
    costCenter   = FStr "CC-02"
    assetCounter = FInt 0
}
Set-FsDoc -Path "areas/A3" -Fields @{
    id           = FStr "A3"
    name         = FStr "Cámaras de Frío"
    costCenter   = FStr "CC-03"
    assetCounter = FInt 0
}

# ================= 4. ACTIVOS DE EJEMPLO (jerarquía 4 niveles) =================
# A1-001 (equipment) con 2 sub-equipos, uno con una parte y ésta con una sub-parte.
# childCounter: siguiente número de hijo de cada documento.

# --- Nivel 1: Equipos de A1 ---
Set-FsDoc -Path "assets/A1-001" -Fields @{
    name              = FStr "Bomba centrífuga"
    brand             = FStr "KSB"
    model             = FStr "Etanorm 80"
    areaId            = FStr "A1"
    stationId         = FStr "S1"
    parentAssetId     = FNull
    level             = FStr "equipment"
    ancestors         = FArrStr @()
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 2
    searchTerms       = FArrStr @("a1", "001", "bomba", "centrifuga", "ksb", "etanorm", "80")
    dynamicAttributes = FMap @{
        potencia  = FStr "7.5 kW"
        caudal    = FStr "60 m3/h"
    }
}
Set-FsDoc -Path "assets/A1-002" -Fields @{
    name              = FStr "Compresor de aire"
    brand             = FStr "Atlas Copco"
    model             = FStr "GA 30"
    areaId            = FStr "A1"
    stationId         = FStr "S2"
    parentAssetId     = FNull
    level             = FStr "equipment"
    ancestors         = FArrStr @()
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a1", "002", "compresor", "de", "aire", "atlas", "copco", "ga", "30")
    dynamicAttributes = FMap @{
        presion = FStr "10 bar"
    }
}

# --- Nivel 2: Sub-equipos de A1-001 ---
Set-FsDoc -Path "assets/A1-001-01" -Fields @{
    name              = FStr "Motor eléctrico"
    brand             = FStr "Siemens"
    model             = FStr "SIMATIC S7-1200"
    areaId            = FStr "A1"
    stationId         = FStr "S1"
    parentAssetId     = FStr "A1-001"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A1-001")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 1
    searchTerms       = FArrStr @("a1", "001", "01", "motor", "electrico", "siemens", "simatic", "s7", "1200")
    dynamicAttributes = FMap @{
        potencia = FStr "5.5 kW"
        voltaje  = FStr "440V"
    }
}
Set-FsDoc -Path "assets/A1-001-02" -Fields @{
    name              = FStr "Sello mecánico"
    brand             = FStr "John Crane"
    model             = FStr "Type 21"
    areaId            = FStr "A1"
    stationId         = FStr "S1"
    parentAssetId     = FStr "A1-001"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A1-001")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a1", "001", "02", "sello", "mecanico", "john", "crane", "type", "21")
    dynamicAttributes = FMap @{
        material = FStr "Carburo de silicio"
    }
}

# --- Nivel 3: Parte del motor eléctrico (A1-001-01) ---
Set-FsDoc -Path "assets/A1-001-01-01" -Fields @{
    name              = FStr "Rodamiento del motor"
    brand             = FStr "SKF"
    model             = FStr "6205-2RS"
    areaId            = FStr "A1"
    stationId         = FStr "S1"
    parentAssetId     = FStr "A1-001-01"
    level             = FStr "part"
    ancestors         = FArrStr @("A1-001", "A1-001-01")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 1
    searchTerms       = FArrStr @("a1", "001", "01", "rodamiento", "del", "motor", "skf", "6205", "2rs")
    dynamicAttributes = FMap @{
        dimension = FStr "25x52x15 mm"
    }
}

# --- Nivel 4: Sub-parte del rodamiento (A1-001-01-01) ---
Set-FsDoc -Path "assets/A1-001-01-01-01" -Fields @{
    name              = FStr "Rótula del rodamiento"
    brand             = FStr "SKF"
    model             = FStr "BALL-6205"
    areaId            = FStr "A1"
    stationId         = FStr "S1"
    parentAssetId     = FStr "A1-001-01-01"
    level             = FStr "subPart"
    ancestors         = FArrStr @("A1-001", "A1-001-01", "A1-001-01-01")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a1", "001", "01", "rotula", "del", "rodamiento", "skf", "ball", "6205")
    dynamicAttributes = FMap @{
        material = FStr "Acero cromado"
    }
}

# ================= 5. REPORTES DE AVERÍA Y ÓRDENES DE TRABAJO =================
# br-001 ya está vinculada a la OT OT-0001 (en_ot); br-002 sigue reportada;
# br-003 fue rechazada con justificación.

Set-FsDoc -Path "breakdown_reports/br-001" -Fields @{
    assetId              = FStr "A1-001"
    assetName            = FStr "Bomba centrífuga"
    areaId               = FStr "A1"
    description          = FStr "Fuga de aceite en el sello mecánico."
    severity             = FStr "high"
    reportedByUserId     = FStr "reportador"
    reportedByUserName   = FStr "reportador"
    reportedAt           = FTime (Get-Date).AddDays(-3)
    status               = FStr "inWorkOrder"
    workOrderId          = FStr "OT-0001"
}

Set-FsDoc -Path "breakdown_reports/br-002" -Fields @{
    assetId              = FStr "A1-002"
    assetName            = FStr "Compresor de aire"
    areaId               = FStr "A1"
    description          = FStr "Ruido excesivo y vibración al arrancar."
    severity             = FStr "medium"
    reportedByUserId     = FStr "reportador"
    reportedByUserName   = FStr "reportador"
    reportedAt           = FTime (Get-Date).AddDays(-1)
    status               = FStr "reported"
}

Set-FsDoc -Path "breakdown_reports/br-003" -Fields @{
    assetId              = FStr "A1-001-01"
    assetName            = FStr "Motor eléctrico"
    areaId               = FStr "A1"
    description          = FStr "Ligera vibración detectada en el motor."
    severity             = FStr "low"
    reportedByUserId     = FStr "reportador"
    reportedByUserName   = FStr "reportador"
    reportedAt           = FTime (Get-Date).AddHours(-20)
    status               = FStr "rejected"
    rejectionReason      = FStr "Vibración dentro de rango aceptable; sin avería."
    rejectedByUserId     = FStr "admin"
    rejectedByUserName   = FStr "Administrador General"
    rejectedAt           = FTime (Get-Date).AddHours(-18)
}

Set-FsDoc -Path "work_orders/OT-0001" -Fields @{
    assetId              = FStr "A1-001"
    assetName            = FStr "Bomba centrífuga"
    description          = FStr "Fuga de aceite en el sello mecánico."
    status               = FStr "pending"
    priority             = FStr "high"
    reportId             = FStr "br-001"
    createdByUserId      = FStr "admin"
    createdByUserName    = FStr "Administrador General"
    createdAt            = FTime (Get-Date).AddDays(-2)
}

Write-Host ""
Write-Host "SEED COMPLETADO"
