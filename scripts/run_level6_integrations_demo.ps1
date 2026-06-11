$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. "$Root\scripts\lib\load_env.ps1" -RepoRoot $Root

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://127.0.0.1:8000" }
$LotId = if ($env:LOT_ID) { $env:LOT_ID } else { "LOT-L6-$(Get-Date -Format yyyyMMddHHmmss)" }
$Headers = @{
  "X-API-Key" = $env:API_KEY
  "X-Actor" = if ($env:ACTOR) { $env:ACTOR } else { "Awon Riaz" }
  "X-Role" = if ($env:ROLE) { $env:ROLE } else { "admin" }
}

Write-Host "Start stack first with: docker compose --profile full up -d --build"
Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET | ConvertTo-Json -Depth 10

Write-Host "1) Create strategic material lot"
$body = @{
  lot_id = $LotId
  material_type = "rare-earth"
  supplier = "Strategic Minerals Ltd"
  origin_country = "Australia"
  metadata = @{ location = "Mumbai Region"; use_case = "semiconductor manufacturing" }
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$BaseUrl/api/v1/materials" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "2) Record custody movement"
$body = @{
  lot_id = $LotId
  event_type = "CUSTODY_TRANSFER"
  location = "Mumbai QC Lab"
  payload = @{ from = "Port"; to = "QC Lab"; sealed_container = $true }
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$BaseUrl/api/v1/trace/events" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "3) TensorFlow inspection"
# PowerShell 7 supports -Form. In Windows PowerShell 5, use Git Bash script or Swagger UI for this endpoint.
$form = @{ file = Get-Item "$Root/sample_data/defective_material.png" }
Invoke-RestMethod -Uri "$BaseUrl/api/v1/quality/tensorflow/inspect?lot_id=$LotId" -Method POST -Headers $Headers -Form $form | ConvertTo-Json -Depth 10

Write-Host "4) Add ESG lifecycle/carbon event"
$body = @{ lot_id = $LotId; stage = "smelting"; co2e_kg = 1200; energy_kwh = 4100; water_l = 850; waste_kg = 17 } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$BaseUrl/api/v1/esg/carbon" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "5) Add strategic material risk assessment"
$body = @{ lot_id = $LotId; material_type = "rare-earth"; origin_country = "Australia"; supplier = "Strategic Minerals Ltd"; supplier_score = 82; region_risk = "high"; single_source = $false; threat_intel_hits = 1 } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$BaseUrl/api/v1/risk/assess" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "6) Sync to Elasticsearch"
Invoke-RestMethod -Uri "$BaseUrl/api/v1/search/sync/$LotId" -Method POST -Headers $Headers | ConvertTo-Json -Depth 10

Write-Host "7) Search Elasticsearch"
Invoke-RestMethod -Uri "$BaseUrl/api/v1/search/materials?q=rare%20earth&size=5" -Method GET -Headers $Headers | ConvertTo-Json -Depth 10

Write-Host "8) Validate tamper-evident chain"
Invoke-RestMethod -Uri "$BaseUrl/api/v1/blockchain/validate?lot_id=$LotId" -Method GET -Headers $Headers | ConvertTo-Json -Depth 10
