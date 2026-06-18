# Upload OpenRouter API key from assets/gemini.txt to Firebase Secret Manager.
# Get a key at https://openrouter.ai/keys (starts with sk-or-v1).

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$keyPath = Join-Path $repoRoot "assets\gemini.txt"

if (-not (Test-Path $keyPath)) {
    Write-Error "Missing assets/gemini.txt. Paste your OpenRouter API key into that file first."
}

$key = (Get-Content -Path $keyPath -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error "assets/gemini.txt is empty."
}

if (-not $key.StartsWith("sk-or")) {
    $prefix = $key.Substring(0, [Math]::Min(8, $key.Length))
    Write-Error "Invalid key format (starts with: $prefix). OpenRouter keys start with sk-or-v1. Get one at https://openrouter.ai/keys"
}

Write-Host "Setting OPENROUTER_API_KEY secret in Firebase..."
$key | firebase functions:secrets:set OPENROUTER_API_KEY

Write-Host "Redeploying chatWithGemini..."
Push-Location $repoRoot
try {
    firebase deploy --only functions:chatWithGemini
} finally {
    Pop-Location
}

Write-Host "Done. Hot restart the app and try the AI chat again."
