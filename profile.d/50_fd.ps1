if (-not ($ProfileTools.fd -and $ProfileTools.fzf)) { return }

# fd has no config file or config variable, so its options live here. Plain `fzf` (no piped input)
# and fzf's own file listing use this command instead of the slower default walker: files only,
# hidden ones included (.gitignore is still honored), .git left out, symlinks followed.
# An FZF_DEFAULT_COMMAND already in the environment wins.
if (-not $env:FZF_DEFAULT_COMMAND) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
}
