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
        throw
    }
}

function FStr([string]$v) { return @{ stringValue = $v } }
function FInt([int]$v) { return @{ integerValue = "$v" } }
function FArrStr([string[]]$v) { return @{ arrayValue = @{ values = @($v | ForEach-Object { @{ stringValue = $_ } }) } } }
function FMap([hashtable]$v) {
    $fields = @{}
    foreach ($k in $v.Keys) { $fields[$k] = $v[$k] }
    return @{ mapValue = @{ fields = $fields } }
}
function FNull() { return @{ nullValue = $null } }

# ================= 1. ÁREA CLASIFICADO (A005) =================
Set-FsDoc -Path "areas/A005" -Fields @{
    id           = FStr "A005"
    name         = FStr "CLASIFICADO"
    costCenter   = FStr "CC-41"
    assetCounter = FInt 2
}

# ================= 2. ACTIVO 1: MESA CLASIFICADORA (A005-001) =================
# Nivel 1: Equipo
Set-FsDoc -Path "assets/A005-001" -Fields @{
    name              = FStr "Mesa Clasificadora de Camarón"
    brand             = FStr "Marel"
    model             = FStr "CS-3000"
    serial            = FStr "SN-CLS-2026-001"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 1 - Recepción de Talla"
    parentAssetId     = FNull
    level             = FStr "equipment"
    ancestors         = FArrStr @()
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 2
    searchTerms       = FArrStr @("a005", "001", "mesa", "clasificadora", "camaron", "marel", "cs", "3000", "sn", "cls")
    dynamicAttributes = FMap @{
        capacidad     = FStr "2500 kg/h"
        material      = FStr "Acero Inoxidable 316L"
        alimentacion  = FStr "220V Trifásico"
    }
}

# Nivel 2: Sub-equipo 1 de A005-001
Set-FsDoc -Path "assets/A005-001-01" -Fields @{
    name              = FStr "Banda Transportadora de Clasificación"
    brand             = FStr "Habasit"
    model             = FStr "FNB-5EQ"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 1 - Recepción de Talla"
    parentAssetId     = FStr "A005-001"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A005-001")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 1
    searchTerms       = FArrStr @("a005", "001", "01", "banda", "transportadora", "clasificacion", "habasit", "fnb")
    dynamicAttributes = FMap @{
        longitud      = FStr "6.5 m"
        ancho         = FStr "800 mm"
    }
}

# Nivel 3: Parte de A005-001-01
Set-FsDoc -Path "assets/A005-001-01-01" -Fields @{
    name              = FStr "Motorreductor de Tracción"
    brand             = FStr "SEW-Eurodrive"
    model             = FStr "WA20-DRN71M4"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 1 - Recepción de Talla"
    parentAssetId     = FStr "A005-001-01"
    level             = FStr "part"
    ancestors         = FArrStr @("A005-001", "A005-001-01")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 1
    searchTerms       = FArrStr @("a005", "001", "01", "motorreductor", "traccion", "sew", "eurodrive", "wa20")
    dynamicAttributes = FMap @{
        potencia      = FStr "1.5 kW"
        rpm_salida    = FStr "45 RPM"
    }
}

# Nivel 4: Sub-parte de A005-001-01-01
Set-FsDoc -Path "assets/A005-001-01-01-01" -Fields @{
    name              = FStr "Rodamiento de Chumaceras"
    brand             = FStr "SKF"
    model             = FStr "YAR 205-2F"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 1 - Recepción de Talla"
    parentAssetId     = FStr "A005-001-01-01"
    level             = FStr "subPart"
    ancestors         = FArrStr @("A005-001", "A005-001-01", "A005-001-01-01")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a005", "001", "01", "rodamiento", "chumaceras", "skf", "yar", "205")
    dynamicAttributes = FMap @{
        diametro_eje  = FStr "25 mm"
    }
}

# Nivel 2: Sub-equipo 2 de A005-001
Set-FsDoc -Path "assets/A005-001-02" -Fields @{
    name              = FStr "Sistema de Rodillos Calibradores"
    brand             = FStr "Marel"
    model             = FStr "RC-Grading"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 1 - Recepción de Talla"
    parentAssetId     = FStr "A005-001"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A005-001")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a005", "001", "02", "sistema", "rodillos", "calibradores", "marel", "rc")
    dynamicAttributes = FMap @{
        num_rodillos  = FStr "8 pares"
        ajuste_luz    = FStr "10-45 mm"
    }
}

# ================= 3. ACTIVO 2: TOLVA DE DOSIFICACIÓN Y LAVADO (A005-002) =================
# Nivel 1: Equipo
Set-FsDoc -Path "assets/A005-002" -Fields @{
    name              = FStr "Tolva de Dosificación y Lavado"
    brand             = FStr "Key Technology"
    model             = FStr "Iso-Flo 500"
    serial            = FStr "SN-CLS-2026-002"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 2 - Pre-selección"
    parentAssetId     = FNull
    level             = FStr "equipment"
    ancestors         = FArrStr @()
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 2
    searchTerms       = FArrStr @("a005", "002", "tolva", "dosificacion", "lavado", "key", "technology", "iso", "flo")
    dynamicAttributes = FMap @{
        volumen       = FStr "1200 Litros"
        presion_asp   = FStr "4.5 bar"
        boquillas     = FStr "12 unidades"
    }
}

# Nivel 2: Sub-equipo 1 de A005-002
Set-FsDoc -Path "assets/A005-002-01" -Fields @{
    name              = FStr "Bomba de Recirculación de Agua Clorada"
    brand             = FStr "Grundfos"
    model             = FStr "CR 15-3"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 2 - Pre-selección"
    parentAssetId     = FStr "A005-002"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A005-002")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 1
    searchTerms       = FArrStr @("a005", "002", "01", "bomba", "recirculacion", "agua", "clorada", "grundfos", "cr")
    dynamicAttributes = FMap @{
        caudal        = FStr "15 m3/h"
        altura_m      = FStr "35 mca"
    }
}

# Nivel 3: Parte de A005-002-01
Set-FsDoc -Path "assets/A005-002-01-01" -Fields @{
    name              = FStr "Sello Mecánico de Bomba"
    brand             = FStr "John Crane"
    model             = FStr "Type 58B"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 2 - Pre-selección"
    parentAssetId     = FStr "A005-002-01"
    level             = FStr "part"
    ancestors         = FArrStr @("A005-002", "A005-002-01")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a005", "002", "01", "sello", "mecanico", "bomba", "john", "crane", "58b")
    dynamicAttributes = FMap @{
        material_caras = FStr "Carburo de Silicio / Carbón"
    }
}

# Nivel 2: Sub-equipo 2 de A005-002
Set-FsDoc -Path "assets/A005-002-02" -Fields @{
    name              = FStr "Sensor de Nivel y Flujo Ultrasónico"
    brand             = FStr "Endress+Hauser"
    model             = FStr "Prosonic FMU30"
    areaId            = FStr "A005"
    stationId         = FStr "Estación 2 - Pre-selección"
    parentAssetId     = FStr "A005-002"
    level             = FStr "subEquipment"
    ancestors         = FArrStr @("A005-002")
    status            = FStr "active"
    transferredToId   = FNull
    childCounter      = FInt 0
    searchTerms       = FArrStr @("a005", "002", "02", "sensor", "nivel", "flujo", "ultrasonico", "endress", "hauser")
    dynamicAttributes = FMap @{
        rango_medicion = FStr "0.25 - 5 m"
        salida_senal   = FStr "4-20 mA HART"
    }
}

Write-Host "`nActivos en el área CLASIFICADO (A005) registrados exitosamente en Firestore."
