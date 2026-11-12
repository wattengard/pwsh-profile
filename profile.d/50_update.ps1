if (-not $ProfileTools.git) { return }

# Background update check for a profile run from a git clone: fetch main from GitHub and count the
# commits this checkout is missing. Fire and forget, with three rules:
#   * It never runs at load for long: at most once per PROFILE_UPDATE_CHECK_HOURS (the time of the
#     last check lives in a small file inside .git), so most shell starts spawn nothing.
#   * It cannot hang: no credential or ssh prompts, and ssh gives up connecting after 10 seconds.
#   * Its result is collected by the prompt (Update-ProfileUpdateState, one property check per
#     prompt, the same way the git status run is), because a child process cannot set variables in
#     this shell. The answer is $global:ProfileUpdateBehind (0 = up to date or unknown), which the
#     prompt turns into a clock icon. A run that is still going when the shell exits is simply lost.
# A profile that is not a clone (a future packaged install) has no .git here and is skipped.

$script:UpdateRepo = Split-Path $PSScriptRoot
$script:UpdateStateFile = [IO.Path]::Combine($script:UpdateRepo, '.git', 'pwsh-profile-update')
if (-not $script:UpdateRun) { $script:UpdateRun = $null }

# The commit this checkout is on, read from .git without a process (Read-GitRef is from 00_prompt).
function script:Get-UpdateHead {
    $gitDir = [IO.Path]::Combine($script:UpdateRepo, '.git')
    $headFile = [IO.Path]::Combine($gitDir, 'HEAD')
    if (-not [IO.File]::Exists($headFile)) { return }
    $head = [IO.File]::ReadAllText($headFile).Trim()
    $head.StartsWith('ref: ') ? (Read-GitRef $gitDir $head.Substring(5)) : $head
}

# The state file holds "<UTC ticks of the last check> <commits behind> <HEAD at that check>". The
# count only means something for that HEAD: after a pull or a new commit it is discarded.
function script:Read-UpdateState {
    if (-not [IO.File]::Exists($script:UpdateStateFile)) { return }
    $parts = [IO.File]::ReadAllText($script:UpdateStateFile).Trim().Split(' ')
    if ($parts.Count -ne 3) { return }
    $ticks = 0L
    $behind = 0
    if ([long]::TryParse($parts[0], [ref]$ticks) -and [int]::TryParse($parts[1], [ref]$behind)) {
        [pscustomobject]@{ Checked = [datetime]::new($ticks, 'Utc'); Behind = $behind; Head = $parts[2] }
    }
}

function script:Write-UpdateState {
    param([datetime]$Checked, [int]$Behind, [string]$Head)
    try { [IO.File]::WriteAllText($script:UpdateStateFile, "$($Checked.Ticks) $Behind $Head") } catch { }
}

function Start-ProfileUpdateCheck {
    <#
    .SYNOPSIS
        Starts the background update check, unless one is running.
    .DESCRIPTION
        Fetches main from origin and counts the commits HEAD is missing, in one hidden git process.
        The prompt collects the result. Does nothing when the profile is not run from a git clone.
    .NOTES
        Requires: git
    #>
    if ($script:UpdateRun -or -not [IO.Directory]::Exists([IO.Path]::Combine($script:UpdateRepo, '.git'))) { return }

    # Record the attempt now, so a check that never finishes (offline, shell closed) is not
    # retried by every new terminal.
    $previous = Read-UpdateState
    $started = [datetime]::UtcNow
    $head = Get-UpdateHead
    Write-UpdateState $started ($previous -and $previous.Head -eq $head ? $previous.Behind : 0) $head

    $psi = [Diagnostics.ProcessStartInfo]::new($ProfileTools.git)
    foreach ($arg in '-C', $script:UpdateRepo, '-c',
        'alias.profile-update-check=!git fetch --quiet --no-tags origin refs/heads/main:refs/remotes/origin/main && git rev-list --count HEAD..origin/main',
        'profile-update-check') { $psi.ArgumentList.Add($arg) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['GIT_TERMINAL_PROMPT'] = '0'
    $psi.Environment['GIT_SSH_COMMAND'] = 'ssh -o BatchMode=yes -o ConnectTimeout=10'

    try { $process = [Diagnostics.Process]::Start($psi) } catch { return }
    $script:UpdateRun = @{ Process = $process; Out = $process.StandardOutput.ReadToEndAsync(); Err = $process.StandardError.ReadToEndAsync(); Started = $started; Head = $head }
}

function Update-ProfileUpdateState {
    <#
    .SYNOPSIS
        Collects a finished background update check and sets the update flag.
    .DESCRIPTION
        Called by the prompt. Cheap when nothing is running. Sets $global:ProfileUpdateBehind to the
        number of commits missing from main, and remembers it for the next shell.
    .NOTES
        Requires: git
    #>
    $run = $script:UpdateRun
    if (-not $run -or -not $run.Process.HasExited -or -not $run.Out.IsCompleted) { return }

    $script:UpdateRun = $null
    $behind = 0
    $ok = $run.Process.ExitCode -eq 0 -and [int]::TryParse(($run.Out.Result.Trim().Split("`n") | Select-Object -Last 1), [ref]$behind)
    $run.Process.Dispose()

    if ($ok) {
        # Only show it if HEAD did not move (a pull) while the check ran.
        if ((Get-UpdateHead) -eq $run.Head) { $global:ProfileUpdateBehind = $behind }
        Write-UpdateState $run.Started $behind $run.Head
    }
}

# Interactive shells only (the prompt collects the result), and only when enabled.
if ($env:PROFILE_UPDATE_CHECK -eq '1' -and -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
    $updateState = Read-UpdateState
    $updateHead = Get-UpdateHead
    # A saved count only holds for the HEAD it was measured on; after a pull, show nothing and recheck.
    $updateKnown = $updateState -and $updateState.Head -eq $updateHead
    $global:ProfileUpdateBehind = $updateKnown ? $updateState.Behind : 0

    $updateHours = $env:PROFILE_UPDATE_CHECK_HOURS -as [int]
    if (-not $updateHours -or $updateHours -lt 1) { $updateHours = 12 }
    if (-not $updateKnown -or ([datetime]::UtcNow - $updateState.Checked).TotalHours -ge $updateHours) {
        Start-ProfileUpdateCheck
    }
    Remove-Variable updateState, updateHead, updateKnown, updateHours -ErrorAction Ignore
}
else {
    $global:ProfileUpdateBehind = 0
}
