param(
    [string] $AwsProfile = 'aptraining-dev'
)

$ErrorActionPreference = 'Stop'
$terraformDir = $PSScriptRoot
$expectedAccountId = '639920117896'

$demoResourceAddresses = @(
    'aws_apigatewayv2_api.demo[0]',
    'aws_apigatewayv2_integration.backend[0]',
    'aws_apigatewayv2_route.backend[0]',
    'aws_apigatewayv2_stage.demo[0]',
    'aws_apigatewayv2_vpc_link.demo[0]',
    'aws_ecs_service.backend_demo[0]',
    'aws_lb.demo_api[0]',
    'aws_lb_listener.demo_api_http[0]',
    'aws_lb_target_group.backend[0]',
    'aws_security_group.api_vpc_link[0]',
    'aws_vpc_security_group_ingress_rule.alb_from_api_vpc_link[0]'
)

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

function Get-CurrentBackendImageTagFromState {
    $stateJson = & terraform "-chdir=$terraformDir" show -json
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo leer el estado Terraform para conservar el tag actual del backend.'
    }

    $state = ($stateJson -join [Environment]::NewLine) | ConvertFrom-Json
    $taskDefinition = $state.values.root_module.resources |
        Where-Object { $_.address -eq 'aws_ecs_task_definition.backend' } |
        Select-Object -First 1
    if ($null -eq $taskDefinition) {
        throw 'No se encontró aws_ecs_task_definition.backend en el estado Terraform.'
    }

    $containers = @($taskDefinition.values.container_definitions | ConvertFrom-Json)
    $backendContainer = $containers | Where-Object { $_.name -eq 'backend' } | Select-Object -First 1
    if ($null -eq $backendContainer -or [string]::IsNullOrWhiteSpace($backendContainer.image)) {
        throw 'No se pudo obtener la imagen actual del contenedor backend desde el estado Terraform.'
    }

    return [string]($backendContainer.image -split ':')[-1]
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

Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'init', '-input=false')
$backendImageTag = Get-CurrentBackendImageTagFromState
Write-Host "Se conservará el tag actual del backend: $backendImageTag"

$planFile = Join-Path ([IO.Path]::GetTempPath()) "aptraining-dev-stop-$PID.tfplan"
try {
    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @(
        "-chdir=$terraformDir", 'plan', '-input=false',
        "-var=aws_profile=$AwsProfile",
        "-var=backend_image_tag=$backendImageTag",
        '-var=enable_demo_api=false',
        "-out=$planFile"
    )

    $planJson = & terraform "-chdir=$terraformDir" show -json $planFile
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo validar el plan Terraform.'
    }
    $plan = ($planJson -join [Environment]::NewLine) | ConvertFrom-Json
    $changes = @($plan.resource_changes | Where-Object { ($_.change.actions -join ',') -ne 'no-op' })
    $unexpectedChanges = @($changes | Where-Object {
        $_.address -notin $demoResourceAddresses -or ($_.change.actions -join ',') -ne 'delete'
    })

    if ($unexpectedChanges.Count -gt 0) {
        $details = $unexpectedChanges | ForEach-Object { "$($_.address): $($_.change.actions -join ',')" }
        throw "El plan incluye cambios fuera del apagado de la API demo; no se aplicará:`n$($details -join "`n")"
    }

    if ($changes.Count -eq 0) {
        Write-Host "`nLa API demo ya está apagada; no hay recursos que eliminar."
        return
    }

    Write-Host "`nPlan validado: solo elimina recursos temporales de la API demo."
    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'show', '-no-color', $planFile)

    $confirmation = Read-Host 'Para apagar la API demo, escribe APAGAR'
    if ($confirmation -cne 'APAGAR') {
        Write-Host 'Cancelado; no se aplicaron cambios.'
        return
    }

    Invoke-CheckedCommand -Command 'terraform' -CommandArgs @("-chdir=$terraformDir", 'apply', '-input=false', $planFile)
    Write-Host 'API demo apagada. RDS, S3 y el resto de la infraestructura persistente no se han eliminado.'
}
finally {
    Remove-Item -LiteralPath $planFile -Force -ErrorAction SilentlyContinue
}
