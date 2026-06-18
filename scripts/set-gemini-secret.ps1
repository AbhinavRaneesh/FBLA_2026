# Upload Gemini API key from assets/gemini.txt to Firebase Secret Manager.
# Get a key at https://aistudio.google.com/apikey (must start with AIzaSy).

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$keyPath = Join-Path $repoRoot "assets\gemini.txt"

if (-not (Test-Path $keyPath)) {
    Write-Error "Missing assets/gemini.txt. Paste your Gemini API key into that file first."
}

$key = (Get-Content -Path $keyPath -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error "assets/gemini.txt is empty. Paste your Gemini API key from https://aistudio.google.com/apikey"
}

if (-not ($key.StartsWith("AIza") -or $key.StartsWith("AQ."))) {
    $prefix = $key.Substring(0, [Math]::Min(8, $key.Length))
    Write-Error "Unrecognized key format in assets/gemini.txt (starts with: $prefix). Use your Postman key (AIzaSy... or AQ....)."
}

Write-Host "Setting GEMINI_API_KEY secret in Firebase..."
$key | firebase functions:secrets:set GEMINI_API_KEY

Write-Host "Redeploying chatWithGemini..."
Push-Location $repoRoot
try {
    firebase deploy --only functions:chatWithGemini
} finally {
    Pop-Location
}

Write-Host "Done. Hot restart the app and try the AI chat again."
