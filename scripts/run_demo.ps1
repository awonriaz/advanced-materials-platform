$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. "$Root\scripts\lib\load_env.ps1" -RepoRoot $Root

$ApiUrl = if ($env:API_URL) { $env:API_URL } else { "http://127.0.0.1:8000" }
$LotId = if ($env:LOT_ID) { $env:LOT_ID } else { "LOT-RE-0001" }
$Headers = @{
  "X-API-Key" = $env:API_KEY
  "X-Actor" = if ($env:ACTOR) { $env:ACTOR } else { "Awon Riaz" }
  "X-Role" = if ($env:ROLE) { $env:ROLE } else { "admin" }
}

Write-Host "1) Health check"
Invoke-RestMethod -Uri "$ApiUrl/health" -Method GET | ConvertTo-Json -Depth 10

Write-Host "2) Create material lot"
$body = @{
  lot_id = $LotId
  material_type = "rare-earth"
  supplier = "Strategic Minerals Ltd"
  origin_country = "Australia"
  metadata = @{ grade = "NdPr oxide"; batch_weight_kg = 250; location = "Mumbai Demo Warehouse" }
} | ConvertTo-Json -Depth 10
try {
  Invoke-RestMethod -Uri "$ApiUrl/api/v1/materials" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10
} catch {
  Write-Host "Material may already exist. Continuing demo with existing lot."
}

Write-Host "3) Add custody transfer"
$body = @{
  lot_id = $LotId
  event_type = "CUSTODY_TRANSFER"
  actor = "Warehouse Operator"
  location = "Mumbai Demo Warehouse"
  payload = @{ from = "Supplier"; to = "QC Lab"; condition = "sealed" }
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$ApiUrl/api/v1/trace/events" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "4) Run AI quality control on good sample"
curl.exe -s -X POST "$ApiUrl/api/v1/quality/inspect?lot_id=$LotId" -H "X-API-Key: $env:API_KEY" -H "X-Actor: Awon Riaz" -H "X-Role: admin" -F "file=@$Root/sample_data/good_material.png"

Write-Host "5) Run AI quality control on defective sample"
curl.exe -s -X POST "$ApiUrl/api/v1/quality/inspect?lot_id=$LotId" -H "X-API-Key: $env:API_KEY" -H "X-Actor: Awon Riaz" -H "X-Role: admin" -F "file=@$Root/sample_data/defective_material.png"

Write-Host "6) Add ESG/carbon event"
$body = @{ lot_id = $LotId; stage = "smelting"; co2e_kg = 120.5; energy_kwh = 450; water_l = 900; waste_kg = 12.4 } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$ApiUrl/api/v1/esg/carbon" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "7) Run strategic material risk assessment"
$body = @{ lot_id = $LotId; material_type = "rare-earth"; origin_country = "Australia"; supplier = "Strategic Minerals Ltd"; supplier_score = 82; region_risk = "low"; single_source = $true; threat_intel_hits = 1 } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$ApiUrl/api/v1/risk/assess" -Method POST -Headers $Headers -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 10

Write-Host "8) Validate blockchain hash chain"
Invoke-RestMethod -Uri "$ApiUrl/api/v1/blockchain/validate?lot_id=$LotId" -Method GET -Headers $Headers | ConvertTo-Json -Depth 10

Write-Host "9) Digital material passport"
Invoke-RestMethod -Uri "$ApiUrl/api/v1/materials/$LotId/passport" -Method GET -Headers $Headers | ConvertTo-Json -Depth 10
