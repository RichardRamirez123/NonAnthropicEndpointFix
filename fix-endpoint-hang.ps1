<#
.SYNOPSIS
    Fixes Claude Code tool calls that hang on a non-Anthropic ANTHROPIC_BASE_URL.

.DESCRIPTION
    Adds CLAUDE_CODE_AUTO_MODE_SERVER = "0" to the env block of settings.json.
    That forces auto mode's LOCAL permission classifier instead of Anthropic's
    server-side one -- which a third-party endpoint (DeepSeek, OpenRouter, a
    gateway or proxy) cannot serve. Tool calls wait on that review, so when it
    never returns the call hangs forever and you have to press Esc.

    Dry run by default: prints what it would change and touches nothing.
    Pass -Apply to write. A timestamped backup is always taken first.

.EXAMPLE
    powershell -File fix-endpoint-hang.ps1
    powershell -File fix-endpoint-hang.ps1 -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
)

$ErrorActionPreference = 'Stop'

function Head($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  ok    $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  warn  $t" -ForegroundColor Yellow }
function Info($t) { Write-Host "  ..    $t" }

Head "Claude Code endpoint-hang fix"
Info "settings: $SettingsPath"

# ---- 1. load settings -------------------------------------------------
Head "1. Settings file"

$exists = Test-Path $SettingsPath
$settings = $null

if (-not $exists) {
    Warn "does not exist yet"
} else {
    $raw = Get-Content $SettingsPath -Raw
    try {
        $settings = $raw | ConvertFrom-Json
        Ok "parsed"
    } catch {
        Warn "could not parse as JSON - not touching it"
        Write-Host ""
        Write-Host "  Fix this one by hand instead. Open:" -ForegroundColor Yellow
        Write-Host "    $SettingsPath"
        Write-Host "  and make sure the top level contains:"
        Write-Host '    "env": { "CLAUDE_CODE_AUTO_MODE_SERVER": "0" }'
        exit 1
    }
}

# ---- 2. which endpoint ------------------------------------------------
Head "2. Endpoint"

$urls = @()
if ($env:ANTHROPIC_BASE_URL) { $urls += "shell:    $env:ANTHROPIC_BASE_URL" }
if ($settings -and $settings.env -and $settings.env.ANTHROPIC_BASE_URL) {
    $urls += "settings: $($settings.env.ANTHROPIC_BASE_URL)"
}
if ($urls.Count -eq 0) {
    Info "ANTHROPIC_BASE_URL not found in this shell or in settings"
} else { $urls | ForEach-Object { Info $_ } }

$host_ = $null
foreach ($u in $urls) {
    if ($u -match 'https?://([^/]+)') { $host_ = $Matches[1] }
}
if ($host_ -and $host_ -ne 'api.anthropic.com') {
    Warn "$host_ is a third-party endpoint - this fix applies"
} elseif ($host_ -eq 'api.anthropic.com') {
    Ok "pointing at api.anthropic.com - this fix is probably not needed"
} else {
    Info "could not determine host"
}

# ---- 3. current state -------------------------------------------------
Head "3. Classifier pin"

$current = $null
if ($settings -and $settings.env) {
    $current = $settings.env.CLAUDE_CODE_AUTO_MODE_SERVER
}

if ($null -eq $current) {
    Warn "CLAUDE_CODE_AUTO_MODE_SERVER not set - server-side classifier may be in use"
} elseif ("$current" -eq "0") {
    Ok "already set to 0 - local classifier pinned, nothing to do"
} else {
    Warn "set to '$current' - expected '0' to force the local classifier"
}

# ---- 4. apply ---------------------------------------------------------
if ($null -ne $current -and "$current" -eq "0") {
    Head "Done"
    Write-Host "  Already fixed on this machine." -ForegroundColor Green
    exit 0
}

Head "4. Change"

$needEnvBlock = $false
if (-not $settings) { $needEnvBlock = $true }
elseif (-not $settings.env) { $needEnvBlock = $true }

if ($needEnvBlock) { Info "will create the env block" }
Info 'will set env.CLAUDE_CODE_AUTO_MODE_SERVER = "0"'

if (-not $Apply) {
    Write-Host ""
    Write-Host "  DRY RUN - nothing was changed." -ForegroundColor Yellow
    Write-Host "  Re-run with -Apply to make the change:" -ForegroundColor Yellow
    Write-Host "    powershell -File fix-endpoint-hang.ps1 -Apply"
    exit 0
}

# backup
if ($exists) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = "$SettingsPath.bak-$stamp"
    Copy-Item $SettingsPath $backup
    Ok "backed up -> $(Split-Path $backup -Leaf)"
}

# ensure env block
if (-not $settings) { $settings = [pscustomobject]@{} }
if (-not $settings.env) {
    $settings | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{}) -Force
}
# set / replace the value
if ($settings.env.PSObject.Properties.Name -contains 'CLAUDE_CODE_AUTO_MODE_SERVER') {
    $settings.env.CLAUDE_CODE_AUTO_MODE_SERVER = "0"
} else {
    $settings.env | Add-Member -NotePropertyName CLAUDE_CODE_AUTO_MODE_SERVER -NotePropertyValue "0"
}

# ensure parent dir exists
$dir = Split-Path $SettingsPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

$json = $settings | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($SettingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))

# verify by re-reading
try {
    $check = (Get-Content $SettingsPath -Raw | ConvertFrom-Json).env.CLAUDE_CODE_AUTO_MODE_SERVER
} catch {
    Warn "wrote the file but could not re-read it - check it by hand"
    exit 1
}

Head "Done"
if ("$check" -eq "0") {
    Write-Host "  Applied and verified." -ForegroundColor Green
} else {
    Write-Host "  Wrote the file but the value reads back as '$check' - check by hand." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Now RESTART Claude Code. The setting is read at startup." -ForegroundColor Yellow
