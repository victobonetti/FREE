# Compila o jogo para um .exe do Windows (versão de lançamento, um arquivo só).
#
#   .\build.ps1            gera build\windows\Free.exe
#   .\build.ps1 -Zip       gera também build\free-windows.zip, pronto para mandar
#   .\build.ps1 -Test      roda os testes antes e só compila se todos passarem
#   .\build.ps1 -Run       abre o jogo compilado no fim
#
# Precisa do Godot 4.7.2 e dos modelos de exportação (export templates) instalados.
# O Godot é procurado em $env:GODOT_EXE ou em C:\Users\victo\Desktop\GODOT.
param(
    [switch]$Zip,
    [switch]$Test,
    [switch]$Run
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { "C:\Users\victo\Desktop\GODOT\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) {
    throw "Godot não encontrado em '$godot'. Defina GODOT_EXE ou ajuste este script."
}

$templates = Join-Path $env:APPDATA "Godot\export_templates"
if (-not (Test-Path $templates) -or -not (Get-ChildItem $templates -ErrorAction SilentlyContinue)) {
    throw "Modelos de exportação não encontrados em '$templates'. No Godot: Editor > Gerenciar modelos de exportação."
}

if ($Test) {
    Write-Host "Rodando os testes..." -ForegroundColor Cyan
    & $godot --headless --path . -s tests/run_tests.gd | Select-String -Pattern "FAIL|FALHAS|TODOS OS TESTES"
    if ($LASTEXITCODE -ne 0) { throw "Testes falharam; nada foi compilado." }
}

$out = "build\windows\Free.exe"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
Remove-Item -Force "build\windows\*" -ErrorAction SilentlyContinue

Write-Host "Importando recursos..." -ForegroundColor Cyan
& $godot --headless --path . --import 2>&1 | Out-Null

Write-Host "Exportando $out ..." -ForegroundColor Cyan
$log = & $godot --headless --path . --export-release "Windows Desktop" $out 2>&1
$log | Select-String -Pattern "ERROR|WARNING" | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
if (-not (Test-Path $out)) { throw "A exportação não gerou '$out'." }

$mb = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host "Pronto: $out ($mb MB)" -ForegroundColor Green

if ($Zip) {
    $zipPath = "build\free-windows.zip"
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Compress-Archive -Path "build\windows\*" -DestinationPath $zipPath
    Write-Host "Zip: $zipPath" -ForegroundColor Green
}

if ($Run) { Start-Process $out }
