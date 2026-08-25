$projectId = "macsapractica"
$token = (gcloud auth print-access-token 2>$null)
if (-not $token) {
    Write-Host "No gcloud token found, using default credentials"
    exit 0
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

$url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/assets"
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$seedIso = (Get-Date).AddDays(-3).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

foreach ($doc in $response.documents) {
    $docName = $doc.name
    $fields = $doc.fields
    $docId = $docName.Split('/')[-1]

    $hasHistory = $fields.statusHistory -ne $null
    if (-not $hasHistory) {
        $status = if ($fields.status.stringValue) { $fields.status.stringValue } else { "active" }
        $areaId = if ($fields.areaId.stringValue) { $fields.areaId.stringValue } else { "" }

        $historyArray = @(
            @{
                mapValue = @{
                    fields = @{
                        status    = @{ stringValue = $status }
                        startedAt = @{ stringValue = $seedIso }
                        areaId    = @{ stringValue = $areaId }
                        reason    = @{ stringValue = "Registro inicial de operaciones" }
                        userName  = @{ stringValue = "Sistema" }
                    }
                }
            }
        )

        $updateBody = @{
            fields = @{
                statusHistory = @{
                    arrayValue = @{
                        values = $historyArray
                    }
                }
                createdAt = @{ stringValue = $seedIso }
            }
        } | ConvertTo-Json -Depth 10

        $patchUrl = "https://firestore.googleapis.com/v1/$docName`?updateMask.fieldPaths=statusHistory&updateMask.fieldPaths=createdAt"
        Invoke-RestMethod -Uri $patchUrl -Headers $headers -Method Patch -Body $updateBody | Out-Null
        Write-Host "Updated asset $docId with initial statusHistory"
    }
}
Write-Host "Backfill completed successfully!"
