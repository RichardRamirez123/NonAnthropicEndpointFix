# check-transcript.ps1
# Objective check for the version-test exercise.
#
# Counts, straight out of the session transcripts, three distinct classes of
# tool-call trouble -- independent of what the model says happened:
#
#   1. PERMISSION DENIAL  - the call was refused rather than failing
#   2. MALFORMED CALL     - the model emitted a mistyped/invalid tool call
#   3. OTHER ERROR        - any remaining tool error
#
# Usage:
#   powershell -File version-test\check-transcript.ps1
#   powershell -File version-test\check-transcript.ps1 -Minutes 30
#
# Implementation notes:
#   - Parses the JSONL and inspects ONLY tool_result blocks, never tool-call
#     inputs. A naive text scan false-positives badly: the signature strings below
#     appear as literal text inside any Write/Edit that creates this file, and
#     inside any fetched page that happens to quote them (the Claude Code
#     changelog quotes several verbatim). Gating on is_error plus tool_result
#     scope keeps the counts to genuine errors.
#   - Class 1 is separated out because a denial is NOT a broken tool. Conflating
#     the two sends you hunting for a version regression when the real cause is
#     permissions or permission mode.

param(
    [string]$Project = "$env:USERPROFILE\.claude\projects\C--Users-richi-Desktop-Notes",
    [int]$Minutes = 60
)

$malformedPatterns = @(
    'No such tool available',
    'InputValidationError',
    'String should have at most 200 characters',
    'unparseable tool call',
    'is not a valid parameter',
    'Missing required parameter',
    'Invalid regular expression',
    'Path contains null bytes'
)

$denialPatterns = @(
    "doesn't want to proceed",
    'was rejected',
    'denied by the Claude Code auto mode classifier',
    'Permission for this action was denied'
)

function Get-BlockText {
    param($Content)
    if ($null -eq $Content) { return "" }
    if ($Content -is [string]) { return $Content }
    $parts = @()
    foreach ($b in $Content) {
        if ($b -is [string]) { $parts += $b; continue }
        if ($b.text) { $parts += $b.text }
        elseif ($b.content) { $parts += (Get-BlockText $b.content) }
    }
    return ($parts -join "`n")
}

if (-not (Test-Path $Project)) {
    "Project transcript directory not found: $Project"
    exit 0
}

$since = (Get-Date).AddMinutes(-$Minutes)
$files = @(Get-ChildItem -Path $Project -Filter *.jsonl -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $since })

if ($files.Count -eq 0) {
    "No transcripts modified in the last $Minutes minute(s) under:"
    "  $Project"
    exit 0
}

"Scanning $($files.Count) transcript(s) modified in the last $Minutes minute(s)."
""

$gDenial = 0
$gMalformed = 0
$gOther = 0

foreach ($f in $files) {
    $denial = 0
    $malformed = 0
    $other = 0
    $detail = @()

    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
        if ($line.IndexOf('is_error') -lt 0) { continue }
        try { $o = $line | ConvertFrom-Json } catch { continue }
        if (-not $o.message) { continue }
        foreach ($b in @($o.message.content)) {
            if ($b.type -ne 'tool_result') { continue }
            if (-not $b.is_error) { continue }
            $txt = Get-BlockText $b.content

            $isDenial = $false
            foreach ($p in $denialPatterns) {
                if ($txt.Contains($p)) { $isDenial = $true; break }
            }
            if ($isDenial) { $denial++; continue }

            $isMalformed = $false
            foreach ($p in $malformedPatterns) {
                if ($txt.Contains($p)) {
                    $isMalformed = $true
                    $detail += "      malformed: $p"
                    break
                }
            }
            if ($isMalformed) { $malformed++ } else { $other++ }
        }
    }

    $gDenial += $denial
    $gMalformed += $malformed
    $gOther += $other

    "  $($f.Name.Substring(0,8))  denials=$denial  malformed=$malformed  other=$other"
    $detail | ForEach-Object { $_ }
}

""
"TOTALS across $($files.Count) transcript(s):"
"  permission denials : $gDenial"
"  malformed calls    : $gMalformed"
"  other tool errors  : $gOther"
""
"Reading:"
if ($gMalformed -gt 0) {
    "  - $gMalformed malformed call(s): the MODEL is emitting bad tool calls."
    "    A version rollback will not fix this; it is model-side."
}
elseif ($gDenial -gt 0) {
    "  - No malformed calls, but $gDenial denial(s): the tools are fine and the"
    "    CALLS were refused. Look at permission mode / the auto-mode classifier,"
    "    not at the build."
}
else {
    "  - Clean: no malformed calls and no denials in this window."
}
