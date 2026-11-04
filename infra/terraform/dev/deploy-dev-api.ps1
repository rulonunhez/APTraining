param(
    [string] $AwsProfile = 'aptraining-dev',
    [string] $BackendImageTag
)

$ErrorActionPreference = 'Stop'
$terraformDir = $PSScriptRoot
$region = 'eu-north-1'
$expectedAccountId = '639920117896'
$repositoryName = 'aptraining-backend-dev'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string] $Command,
        [Parameter(Mandatory = $true)][string[]] $CommandArgs
    )

    & $Command @CommandArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Falló el comando '$Command' con código $LASTEXITCODE."
    }
}

function Get-LatestBackendImageTag {
    $imageJson = & aws ecr describe-images `
        --repository-name $repositoryName `
        --region $region `
        --profile $AwsProfile `
        --output json
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudieron consultar las imágenes del repositorio ECR.'
    }

    $imageData = ($imageJson -join [Environment]::NewLine) | ConvertFrom-Json
    $latestImage = $imageData.imageDetails |
        Where-Object { $_.imageTags -and $_.imagePushedAt } |
        Sort-Object { [datetime]$_.imagePushedAt } -Descending |
        Select-Object -First 1

    if ($null -eq $latestImage) {
        throw "No hay imágenes etiquetadas en ECR/$repositoryName. Primero publica una imagen del backend."
    }

    return [string](@($latestImage.imageTags)[0])
}

Write-Host "Autenticando con AWS mediante el perfil '$AwsProfile'..."
Invoke-CheckedCommand -Command 'aws' -CommandArgs @('sso', 'login', '--profile', $AwsProfile)
$env:AWS_PROFILE = $AwsProfile

$accountId = & aws sts get-caller-identity --profile $AwsProfile --query Account --output text
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo comprobar la cuenta AWS activa.'
}
if ($accountId -ne $expectedAccountId) {
    throw "El perfil '$AwsProfile' apunta a la cuenta $accountId; se esperaba $expectedAccountId. No se aplicó Terraform."
}

if ([string]::IsNullOrWhiteSpace($BackendImageTag)) {
    $BackendImageTag = Get-LatestBackendImageTag
}
Write-Host "Imagen del backend que se desplegará: $BackendImageTag"

Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'init', '-input=false')

$planFile = Join-Path ([IO.Path]::GetTempPath()) "aptraining-dev-deploy-$PID.tfplan"
try {
    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @(
        "-chdir=$terraformDir", 'plan', '-input=false',
        "-var=aws_profile=$AwsProfile",
        "-var=backend_image_tag=$BackendImageTag",
        '-var=enable_demo_api=true',
        "-out=$planFile"
    )

    Write-Host "`nPlan que se va a aplicar:"
    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'show', '-no-color', $planFile)

    $confirmation = Read-Host "Revisa el plan. Escribe APLICAR para desplegar la API demo con la imagen $BackendImageTag"
    if ($confirmation -cne 'APLICAR') {
        Write-Host 'Cancelado; no se aplicaron cambios.'
        return
    }

    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'apply', '-input=false', $planFile)

    $apiUrl = & terraform "-chdir=$terraformDir" output -raw demo_api_url
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($apiUrl)) {
        Write-Host "API demo desplegada: $apiUrl"
    }
}
finally {
    Remove-Item -LiteralPath $planFile -Force -ErrorAction SilentlyContinue
}
