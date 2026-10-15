# EDITOR target for micro. Run as: pwsh -NoProfile -File micro-edit.ps1 <file> ...
#
# Claude Code starts $EDITOR itself (Ctrl+G edits the prompt), not through the shell profile, so
# the `micro` alias in profile.d\50_micro.ps1 never applies there, and micro stops responding in
# Claude Code's terminal. This script does the same job outside the profile: inside Claude Code it
# opens micro in its own window and waits for it to close, anywhere else it just runs micro.
#
# Set MICRO_EDIT_DEBUG=1 to append how it was started to micro-edit.log in the temp folder.

$micro = (Get-Command micro -CommandType Application -ErrorAction Ignore | Select-Object -First 1).Source
if (-not $micro) { Write-Error 'micro is not on PATH'; exit 1 }

function Test-InsideClaude {
    if ($env:CLAUDECODE -or $env:CLAUDE_CODE_ENTRYPOINT) { return $true }

    # The variables may not reach the editor, so also look for claude among the ancestors.
    $byId = @{}
    foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name) { $byId[[int]$p.ProcessId] = $p }
    $id = [int]$PID
    for ($depth = 0; $depth -lt 12 -and $byId.ContainsKey($id); $depth++) {
        $current = $byId[$id]
        if ($current.Name -like 'claude*') { return $true }
        $id = [int]$current.ParentProcessId
    }
    $false
}

$inside = Test-InsideClaude
if ($env:MICRO_EDIT_DEBUG) {
    $line = '{0:s} inside={1} CLAUDECODE={2} ENTRYPOINT={3} cwd={4} args={5}' -f (Get-Date), $inside, $env:CLAUDECODE, $env:CLAUDE_CODE_ENTRYPOINT, (Get-Location).Path, ($args -join '|')
    Add-Content (Join-Path ([IO.Path]::GetTempPath()) 'micro-edit.log') $line
}

if (-not $inside) {
    & $micro @args
    exit $LASTEXITCODE
}

# Start-Process joins the arguments with spaces and does not quote them, so quote the ones that
# need it. The new window starts in the current folder.
$microArgs = foreach ($arg in $args) {
    if ($arg -match '[\s"]') { '"' + ($arg -replace '"', '\"') + '"' } else { "$arg" }
}
$startArgs = @{ FilePath = $micro; WorkingDirectory = (Get-Location).ProviderPath; Wait = $true; PassThru = $true }
if ($microArgs) { $startArgs.ArgumentList = $microArgs }
$process = Start-Process @startArgs
exit $process.ExitCode
