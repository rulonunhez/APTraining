param(
    [switch] $SmokeTest,
    [string] $ApiBaseUrl
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$terraformDir = Join-Path $repoRoot 'infra\terraform\dev'
$mobileDir = Join-Path $repoRoot 'mobile'

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = (& terraform "-chdir=$terraformDir" output -raw demo_api_url).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
        throw 'No se pudo leer demo_api_url de Terraform. Comprueba que la API demo está aplicada y habilitada, o especifica -ApiBaseUrl.'
    }
}
if (-not $ApiBaseUrl.StartsWith('https://')) {
    throw "La URL de DEV debe usar HTTPS; se recibió: $ApiBaseUrl"
}

$flutterArgs = @(
    'build', 'apk', '--release',
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
)
if ($SmokeTest) {
    $flutterArgs += '--dart-define=CRASHLYTICS_SMOKE_TEST=true'
}

Push-Location $mobileDir
try {
    flutter @flutterArgs

    if ($LASTEXITCODE -ne 0) {
        throw 'Falló la compilación Flutter de la APK DEV.'
    }
}
finally {
    Pop-Location
}

Write-Host "APK DEV generada: $(Join-Path $mobileDir 'build\app\outputs\flutter-apk\app-release.apk')"
Write-Host "API configurada: $ApiBaseUrl"
