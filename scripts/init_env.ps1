param(
  [switch]$Rotate
)

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$EnvFile = if ($env:ENV_FILE) { $env:ENV_FILE } else { Join-Path $RootDir ".env" }

function New-Secret {
  $bytes = New-Object byte[] 48
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToBase64String($bytes).Replace("+","-").Replace("/","_").TrimEnd("=")
}

function Get-EnvValue([string]$Key) {
  if (!(Test-Path $EnvFile)) { return "" }
  $line = Get-Content $EnvFile | Where-Object { $_ -like "$Key=*" } | Select-Object -Last 1
  if ($null -eq $line) { return "" }
  return $line.Substring($Key.Length + 1)
}

function Set-EnvValue([string]$Key, [string]$Value) {
  $lines = if (Test-Path $EnvFile) { Get-Content $EnvFile } else { @() }
  $out = New-Object System.Collections.Generic.List[string]
  $replaced = $false
  foreach ($line in $lines) {
    if ($line.StartsWith("$Key=") -and -not $replaced) {
      $out.Add("$Key=$Value")
      $replaced = $true
    } else {
      $out.Add($line)
    }
  }
  if (-not $replaced) { $out.Add("$Key=$Value") }
  Set-Content -Path $EnvFile -Value $out
}

function Is-Blocked([string]$Value) {
  $blocked = @("", "change-this-demo-key", "your-api-key", "paste-your-api-key-here", "replace-me")
  return $blocked -contains $Value
}

if (!(Test-Path $EnvFile)) {
  Copy-Item (Join-Path $RootDir ".env.example") $EnvFile
}

if ($Rotate -or (Is-Blocked (Get-EnvValue "API_KEY"))) {
  Set-EnvValue "API_KEY" (New-Secret)
}
if ([string]::IsNullOrWhiteSpace((Get-EnvValue "MQTT_USERNAME"))) {
  Set-EnvValue "MQTT_USERNAME" "amscp_demo"
}
if ($Rotate -or [string]::IsNullOrWhiteSpace((Get-EnvValue "MQTT_PASSWORD"))) {
  Set-EnvValue "MQTT_PASSWORD" (New-Secret)
}

Write-Output "[OK] .env is ready. API_KEY and MQTT_PASSWORD are set but were not printed."
