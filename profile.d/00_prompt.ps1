# Two-line prompt modeled on "pure": blank line, path (+ git branch), then a caret.
# The caret turns red when the previous command failed.
#
# Git info never spawns git: it walks up to the nearest .git and reads HEAD and a few
# marker files directly, so cost is a handful of file-system calls regardless of repo size.

$script:GitIcon = @{
    Branch   = [string][char]0xF418  # nf-oct-git_branch
    Detached = [string][char]0xF417  # nf-oct-git_commit
}

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

    $headFile = [IO.Path]::Combine($gitDir, 'HEAD')
    if (-not [IO.File]::Exists($headFile)) { return }
    $head = [IO.File]::ReadAllText($headFile).Trim()

    if ($head.StartsWith('ref: refs/heads/')) {
        $name = $head.Substring(16)
        $icon = $script:GitIcon.Branch
    }
    else {
        $name = $head.Substring(0, [Math]::Min(7, $head.Length))
        $icon = $script:GitIcon.Detached
    }

    $state = if ([IO.Directory]::Exists("$gitDir/rebase-merge") -or [IO.Directory]::Exists("$gitDir/rebase-apply")) { 'rebase' }
    elseif ([IO.File]::Exists("$gitDir/MERGE_HEAD")) { 'merge' }
    elseif ([IO.File]::Exists("$gitDir/CHERRY_PICK_HEAD")) { 'cherry-pick' }
    elseif ([IO.File]::Exists("$gitDir/REVERT_HEAD")) { 'revert' }
    elseif ([IO.File]::Exists("$gitDir/BISECT_LOG")) { 'bisect' }

    "$icon $name" + ($state ? " |$state" : '')
}

function prompt {
    $succeeded = $?

    $path = $PWD.ProviderPath
    $display = $path.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase) ? '~' + $path.Substring($HOME.Length) : $path

    $git = ''
    if ($PWD.Provider.Name -eq 'FileSystem') {
        $info = Get-GitPromptInfo $path
        if ($info) { $git = " $($PSStyle.Foreground.BrightBlack)$info" }
    }

    $caretColor = $succeeded ? $PSStyle.Foreground.Magenta : $PSStyle.Foreground.Red

    "`n$($PSStyle.Foreground.Blue)$display$git$($PSStyle.Reset)`n$caretColor❯$($PSStyle.Reset) "
}
