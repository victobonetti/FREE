# Roda o jogo. Uso: .\run.ps1            (jogo normal)
#                  .\run.ps1 -Console    (com console, para ver erros/prints)
#                  .\run.ps1 -Editor     (abre no editor do Godot)
#                  .\run.ps1 -Level 11   (abre direto no nível 11, pulando a abertura)
param(
    [switch]$Console,
    [switch]$Editor,
    [switch]$Fases,
    [int]$Level = 0
)

$ErrorActionPreference = "Stop"

# Caminho do Godot: variável de ambiente GODOT_EXE, ou o local padrão desta máquina.
$dir = "C:\Users\victo\Desktop\GODOT"
$exe = if ($Console) { "Godot_v4.7.2-stable_win64_console.exe" } else { "Godot_v4.7.2-stable_win64.exe" }
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { Join-Path $dir $exe }

if (-not (Test-Path $godot)) {
    Write-Error "Godot não encontrado em '$godot'. Ajuste `$dir em run.ps1 ou defina GODOT_EXE."
}

$args_ = @("--path", $PSScriptRoot)
if ($Editor) { $args_ += "--editor" }
if ($Level -gt 0) { $args_ += @("--", "--level=$Level") }
if ($Fases) { $args_ += @("--", "--editor") }

& $godot @args_
