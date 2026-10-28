Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'cleaner.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw ($parseErrors | ForEach-Object { $_.ToString() } | Out-String)
}

# Load only the reviewed helper definitions; do not run the WPF or registry code.
$names = @('Get-UninstallerExecutable', 'Test-UninstallCommandBroken', 'Get-ValueSafely', 'Convert-ToSafeFileName')
foreach ($name in $names) {
    $definitions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true))
    if ($definitions.Count -ne 1) { throw "Expected one helper: $name" }
    Invoke-Expression $definitions[0].Extent.Text
}

$script:checks = 0
function Assert-Equal {
    param($Actual, $Expected, [string]$Label)
    if ($Actual -cne $Expected) { throw "Failed: $Label" }
    $script:checks++
}

Assert-Equal (Get-UninstallerExecutable '"C:\Program Files\Sample App\uninstall.exe" /quiet') 'C:\Program Files\Sample App\uninstall.exe' 'quoted path'
Assert-Equal (Get-UninstallerExecutable 'C:\Program Files\Sample App\uninstall.exe /quiet') 'C:\Program Files\Sample App\uninstall.exe' 'unquoted path with spaces'
Assert-Equal (Get-UninstallerExecutable 'msiexec.exe /x {EXAMPLE}') 'msiexec.exe' 'PATH command'
Assert-Equal (Get-UninstallerExecutable '"%SystemRoot%\System32\msiexec.exe" /x {EXAMPLE}') "$env:SystemRoot\System32\msiexec.exe" 'environment expansion'
Assert-Equal (Get-UninstallerExecutable '') $null 'empty command'
Assert-Equal (Get-UninstallerExecutable 'rundll32 setup.dll,Entry') $null 'unrecognized command'

$existingExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $existingExe -PathType Leaf)) { throw 'Windows PowerShell fixture missing' }
Assert-Equal (Test-UninstallCommandBroken ('"' + $existingExe + '" -NoProfile')) $false 'existing executable'
$missingExe = Join-Path ([IO.Path]::GetTempPath()) ('BrokenAppsCleaner-missing-' + [guid]::NewGuid().ToString('N') + '.exe')
Assert-Equal (Test-UninstallCommandBroken ('"' + $missingExe + '" /quiet')) $true 'missing executable'
Assert-Equal (Test-UninstallCommandBroken '') $false 'empty command skipped'
Assert-Equal (Test-UninstallCommandBroken 'rundll32 setup.dll,Entry') $false 'unrecognized command skipped'
Assert-Equal (Test-UninstallCommandBroken 'msiexec.exe /x {EXAMPLE}') $false 'existing PATH executable'

$sample = [pscustomobject]@{DisplayName = 'Sample'}
Assert-Equal (Get-ValueSafely $sample 'DisplayName') 'Sample' 'existing property'
Assert-Equal (Get-ValueSafely $sample 'Absent') $null 'absent property'
Assert-Equal (Convert-ToSafeFileName 'A:B/C*D?') 'A_B_C_D_' 'invalid filename characters'
Assert-Equal (Convert-ToSafeFileName '   ') 'RegistryEntry' 'blank filename'
Assert-Equal (Convert-ToSafeFileName ('x' * 100)).Length 90 'filename length limit'
Write-Output "PASS: source parses; $script:checks isolated checks; no registry edits or GUI launch."
