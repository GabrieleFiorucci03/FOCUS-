param(
    [string]$Asset,
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'generate_realistic_assets.py'
$blenderCommand = Get-Command blender -ErrorAction SilentlyContinue

if ($blenderCommand) {
    $blenderPath = $blenderCommand.Source
} else {
    $searchRoots = @(
        'C:\Program Files\Blender Foundation',
        'C:\Program Files (x86)\Blender Foundation',
        (Join-Path $env:LOCALAPPDATA 'Programs\Blender Foundation')
    )
    $blenderPath = $null
    foreach ($searchRoot in $searchRoots) {
        if (Test-Path -LiteralPath $searchRoot) {
            $candidate = Get-ChildItem -LiteralPath $searchRoot -Filter blender.exe -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending |
                Select-Object -First 1
            if ($candidate) {
                $blenderPath = $candidate.FullName
                break
            }
        }
    }
}

if (-not $blenderPath) {
    throw 'Blender non trovato. Installa Blender 4.x o successivo oppure aggiungi blender.exe al PATH.'
}

$arguments = @('--background', '--python', $scriptPath, '--')
if ($Asset) {
    $arguments += @('--asset', $Asset)
}
if ($Output) {
    $arguments += @('--output', $Output)
}

& $blenderPath @arguments
exit $LASTEXITCODE
