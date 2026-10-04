# Two-line prompt modeled on "pure": blank line, path (+ git info), then a caret.
# The caret turns red when the previous command failed.
#
# Git info is read straight from .git (a handful of file-system calls, no process) for the
# branch, in-progress operation and commit subject. Working tree state is the one exception:
# it needs `git status`, which runs once per prompt under a time cap and is cached (see
# Get-GitStatusSummary). Everything else stays process-free.
#
# Config (see config.ps1):
#   PROMPT_GIT_MESSAGE            1/0  show the current commit subject
#   PROMPT_GIT_MESSAGE_WIDTH      max characters of the subject
#   PROMPT_GIT_STATE              1/0  show working tree state
#   PROMPT_GIT_STATE_TIMEOUT_MS   how long to wait for git status

$script:GitIcon = @{
    Branch     = [string][char]0xF418  # nf-oct-git_branch
    Detached   = [string][char]0xF417  # nf-oct-git_commit
    Staged     = [string][char]0xF00C  # nf-fa-check
    Modified   = [string][char]0xF040  # nf-fa-pencil
    Untracked  = [string][char]0xF128  # nf-fa-question
    Conflicted = [string][char]0xF071  # nf-fa-warning
    Ahead      = [string][char]0x21E1  # ⇡
    Behind     = [string][char]0x21E3  # ⇣
}

# The subject only changes when HEAD moves, so remember the last one by SHA.
$script:GitMessageCache = @{ Sha = $null; Text = $null }

# Per-repo status cache, keyed by git dir. Each entry: Summary, Stamp, Time, Pending.
$script:GitStatusCache = @{}

function script:Get-GitPromptInfo {
    param([string]$Path)

    # Find the nearest .git (directory, or a file for worktrees/submodules).
    $dir = $Path
    while ($dir) {
        $dotGit = [IO.Path]::Combine($dir, '.git')
        if ([IO.Directory]::Exists($dotGit)) { $gitDir = $dotGit; break }
        if ([IO.File]::Exists($dotGit)) {
            $pointer = [IO.File]::ReadAllText($dotGit).Trim()
            if (-not $pointer.StartsWith('gitdir: ')) { return }
            $gitDir = [IO.Path]::GetFullPath($pointer.Substring(8), $dir)
            break
        }
        $dir = [IO.Path]::GetDirectoryName($dir)
    }
    if (-not $gitDir) { return }

    # Worktrees keep refs and objects in a shared common dir.
    $commonFile = [IO.Path]::Combine($gitDir, 'commondir')
    $commonDir = [IO.File]::Exists($commonFile) ?
        [IO.Path]::GetFullPath([IO.File]::ReadAllText($commonFile).Trim(), $gitDir) : $gitDir

    $headFile = [IO.Path]::Combine($gitDir, 'HEAD')
    if (-not [IO.File]::Exists($headFile)) { return }
    $head = [IO.File]::ReadAllText($headFile).Trim()

    if ($head.StartsWith('ref: ')) {
        $ref = $head.Substring(5)
        $name = $ref.StartsWith('refs/heads/') ? $ref.Substring(11) : $ref
        $icon = $script:GitIcon.Branch
        $sha = Read-GitRef $commonDir $ref
    }
    else {
        $sha = $head
        $name = $head.Substring(0, [Math]::Min(7, $head.Length))
        $icon = $script:GitIcon.Detached
    }

    $operation = if ([IO.Directory]::Exists("$gitDir/rebase-merge") -or [IO.Directory]::Exists("$gitDir/rebase-apply")) { 'rebase' }
    elseif ([IO.File]::Exists("$gitDir/MERGE_HEAD")) { 'merge' }
    elseif ([IO.File]::Exists("$gitDir/CHERRY_PICK_HEAD")) { 'cherry-pick' }
    elseif ([IO.File]::Exists("$gitDir/REVERT_HEAD")) { 'revert' }
    elseif ([IO.File]::Exists("$gitDir/BISECT_LOG")) { 'bisect' }

    [pscustomobject]@{
        Icon      = $icon
        Name      = $name
        Operation = $operation
        GitDir    = $gitDir
        CommonDir = $commonDir
        Sha       = $sha
    }
}

# Resolve a ref to a SHA from its loose file, falling back to packed-refs.
function script:Read-GitRef {
    param([string]$CommonDir, [string]$Ref)

    $file = [IO.Path]::Combine($CommonDir, $Ref)
    if ([IO.File]::Exists($file)) { return [IO.File]::ReadAllText($file).Trim() }

    $packed = [IO.Path]::Combine($CommonDir, 'packed-refs')
    if ([IO.File]::Exists($packed)) {
        $suffix = " $Ref"
        foreach ($line in [IO.File]::ReadLines($packed)) {
            if ($line.EndsWith($suffix)) { return $line.Substring(0, 40) }
        }
    }
}

# Tier 1: last HEAD reflog entry, if it is a commit that produced the current SHA.
function script:Read-GitReflogSubject {
    param([string]$GitDir, [string]$Sha)

    $file = [IO.Path]::Combine($GitDir, 'logs', 'HEAD')
    if (-not [IO.File]::Exists($file)) { return }

    $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
    try {
        $len = [int][Math]::Min($fs.Length, 4096)
        $truncated = $fs.Length -gt $len
        $null = $fs.Seek(-$len, 'End')
        $buf = [byte[]]::new($len)
        $null = $fs.Read($buf, 0, $len)
    }
    finally { $fs.Dispose() }

    $text = [Text.Encoding]::UTF8.GetString($buf).TrimEnd()
    $nl = $text.LastIndexOf("`n")
    if ($nl -lt 0 -and $truncated) { return }
    $line = $text.Substring($nl + 1)

    # "<old> <new> Name <email> <ts> <tz>\t<action>: <message>"
    $tab = $line.IndexOf("`t")
    if ($tab -lt 81 -or $line.Substring(41, 40) -ne $Sha) { return }
    $entry = $line.Substring($tab + 1)
    if (-not $entry.StartsWith('commit')) { return }
    $colon = $entry.IndexOf(': ')
    if ($colon -ge 0) { $entry.Substring($colon + 2) }
}

# Tier 2: decompress the loose commit object. Packed objects are not handled here.
function script:Read-GitLooseSubject {
    param([string]$CommonDir, [string]$Sha)

    if ($Sha.Length -ne 40) { return }
    $file = [IO.Path]::Combine($CommonDir, 'objects', $Sha.Substring(0, 2), $Sha.Substring(2))
    if (-not [IO.File]::Exists($file)) { return }

    $fs = [IO.File]::OpenRead($file)
    try {
        $zlib = [IO.Compression.ZLibStream]::new($fs, [IO.Compression.CompressionMode]::Decompress)
        $text = [IO.StreamReader]::new($zlib).ReadToEnd()
    }
    finally { $fs.Dispose() }

    if (-not $text.StartsWith('commit ')) { return }
    $body = $text.IndexOf("`n`n")
    if ($body -lt 0) { return }
    $rest = $text.Substring($body + 2)
    $end = $rest.IndexOf("`n")
    $end -ge 0 ? $rest.Substring(0, $end) : $rest
}

function script:Get-GitCommitSubject {
    param($Info, [string]$Path)

    $sha = $Info.Sha
    if (-not $sha) { return }

    $cache = $script:GitMessageCache
    if ($cache.Sha -eq $sha) { return $cache.Text }

    $subject = Read-GitReflogSubject $Info.GitDir $sha
    if (-not $subject) { $subject = Read-GitLooseSubject $Info.CommonDir $sha }
    # Tier 3: packed object, spawn git once; the cache makes it once per commit.
    if (-not $subject) { $subject = (git -C $Path log -1 --format=%s $sha 2>$null | Select-Object -First 1) }

    $cache.Sha = $sha
    $cache.Text = $subject
    $subject
}

# Parse `git status --porcelain=v2 --branch` output into counts.
function script:ConvertFrom-GitStatus {
    param([string]$Text)

    $s = @{ Ahead = 0; Behind = 0; Staged = 0; Modified = 0; Untracked = 0; Conflicted = 0 }
    foreach ($line in $Text.Split("`n")) {
        if ($line.Length -lt 2) { continue }
        switch ($line[0]) {
            '#' {
                if ($line.StartsWith('# branch.ab ')) {
                    $ab = $line.Substring(12).Split(' ')
                    $s.Ahead = [int]$ab[0].Substring(1)
                    $s.Behind = [int]$ab[1].Substring(1)
                }
            }
            { $_ -in '1', '2' } {
                if ($line[2] -ne '.') { $s.Staged++ }
                if ($line[3] -ne '.') { $s.Modified++ }
            }
            'u' { $s.Conflicted++ }
            '?' { $s.Untracked++ }
        }
    }
    $s
}

# One time-capped `git status` per prompt. The result is cached per repo and reused while the
# index and HEAD are unchanged and it is under two seconds old. If git is not done within the
# timeout, the process is left running, the last known state is shown, and the next prompt
# picks up the result, so a huge repo never blocks the prompt for more than the cap.
function script:Get-GitStatusSummary {
    param($Info, [string]$Path)

    $cache = $script:GitStatusCache[$Info.GitDir]
    if (-not $cache) {
        $cache = $script:GitStatusCache[$Info.GitDir] = @{ Summary = $null; Stamp = $null; Time = [datetime]::MinValue; Pending = $null }
    }

    # Collect a run that outlived its timeout on an earlier prompt.
    $pending = $cache.Pending
    if ($pending -and $pending.Process.HasExited) {
        if ($pending.Process.ExitCode -eq 0) {
            $cache.Summary = ConvertFrom-GitStatus $pending.Out.Result
            $cache.Stamp = $pending.Stamp
            $cache.Time = $pending.Started
        }
        $pending.Process.Dispose()
        $cache.Pending = $pending = $null
    }

    $indexFile = [IO.Path]::Combine($Info.GitDir, 'index')
    $stamp = "$($Info.Sha)|$([IO.File]::GetLastWriteTimeUtc($indexFile).Ticks)"
    $fresh = $cache.Stamp -eq $stamp -and ([datetime]::UtcNow - $cache.Time).TotalSeconds -lt 2
    if ($fresh -or $pending) { return $cache.Summary }

    $psi = [Diagnostics.ProcessStartInfo]::new($ProfileTools.git)
    foreach ($arg in '--no-optional-locks', 'status', '--porcelain=v2', '--branch') { $psi.ArgumentList.Add($arg) }
    $psi.WorkingDirectory = $Path
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8

    $started = [datetime]::UtcNow
    $process = [Diagnostics.Process]::Start($psi)
    $run = @{ Process = $process; Out = $process.StandardOutput.ReadToEndAsync(); Err = $process.StandardError.ReadToEndAsync(); Stamp = $stamp; Started = $started }

    $timeout = $env:PROMPT_GIT_STATE_TIMEOUT_MS -as [int]
    if (-not $timeout -or $timeout -lt 1) { $timeout = 150 }
    if ($process.WaitForExit($timeout)) {
        if ($process.ExitCode -eq 0) {
            $cache.Summary = ConvertFrom-GitStatus $run.Out.Result
            $cache.Stamp = $stamp
            $cache.Time = $started
        }
        $process.Dispose()
    }
    else {
        $cache.Pending = $run
    }
    $cache.Summary
}

# Colored state segments, e.g. "⇡1 ✓2 ✎1 ?3", or '' when the tree is clean and in sync.
function script:Format-GitState {
    param($Summary)

    $fg = $PSStyle.Foreground
    $parts = @(
        if ($Summary.Conflicted) { "$($fg.Red)$($script:GitIcon.Conflicted)$($Summary.Conflicted)" }
        if ($Summary.Ahead) { "$($fg.Cyan)$($script:GitIcon.Ahead)$($Summary.Ahead)" }
        if ($Summary.Behind) { "$($fg.Magenta)$($script:GitIcon.Behind)$($Summary.Behind)" }
        if ($Summary.Staged) { "$($fg.Green)$($script:GitIcon.Staged)$($Summary.Staged)" }
        if ($Summary.Modified) { "$($fg.Yellow)$($script:GitIcon.Modified)$($Summary.Modified)" }
        if ($Summary.Untracked) { "$($fg.Blue)$($script:GitIcon.Untracked)$($Summary.Untracked)" }
    )
    $parts -join ' '
}

function prompt {
    $succeeded = $?

    $path = $PWD.ProviderPath
    $display = $path.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase) ? '~' + $path.Substring($HOME.Length) : $path

    $grey = $PSStyle.Foreground.BrightBlack
    $git = ''
    if ($PWD.Provider.Name -eq 'FileSystem') {
        $info = Get-GitPromptInfo $path
        if ($info) {
            $text = "$grey$($info.Icon) $($info.Name)"

            if ($env:PROMPT_GIT_STATE -eq '1' -and $ProfileTools.git) {
                $summary = Get-GitStatusSummary $info $path
                $state = $summary ? (Format-GitState $summary) : ''
                if ($state) { $text += " $state$grey" }
            }

            if ($info.Operation) { $text += " |$($info.Operation)" }

            if ($env:PROMPT_GIT_MESSAGE -eq '1') {
                $subject = Get-GitCommitSubject $info $path
                if ($subject) {
                    $width = $env:PROMPT_GIT_MESSAGE_WIDTH -as [int]
                    if (-not $width -or $width -lt 2) { $width = 40 }
                    if ($subject.Length -gt $width) { $subject = $subject.Substring(0, $width - 1) + '…' }
                    $text += " · $subject"
                }
            }
            $git = " $text"
        }
    }

    $caretColor = $succeeded ? $PSStyle.Foreground.Magenta : $PSStyle.Foreground.Red

    "`n$($PSStyle.Foreground.Blue)$display$git$($PSStyle.Reset)`n$caretColor❯$($PSStyle.Reset) "
}
