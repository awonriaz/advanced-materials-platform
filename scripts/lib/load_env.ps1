param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [string]$EnvFile = ""
)

if ([string]::IsNullOrWhiteSpace($EnvFile)) {
  $EnvFile = Join-Path $RepoRoot ".env"
}

if (-not (Test-Path $EnvFile)) {
  throw "Missing environment file: $EnvFile. Create it with: copy .env.example .env ; then set API_KEY inside .env. Do not commit .env."
}

Get-Content $EnvFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) { return }
  $idx = $line.IndexOf("=")
  if ($idx -le 0) { return }
  $name = $line.Substring(0, $idx).Trim()
  $value = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
  if ($name -match '^[A-Za-z_][A-Za-z0-9_]*$') {
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

if ([string]::IsNullOrWhiteSpace($env:API_KEY)) {
  throw "API_KEY is not set. Add API_KEY to $EnvFile."
}
