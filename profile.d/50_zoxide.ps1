if (-not $ProfileTools.zoxide) { return }

# Directories zoxide should never learn: home itself and temp folders.
if (-not $env:_ZO_EXCLUDE_DIRS) { $env:_ZO_EXCLUDE_DIRS = "$HOME;$env:TEMP;$env:TEMP\*" }

# cdi's fzf window previews the highlighted directory with eza, when eza is available.
if (-not $env:_ZO_FZF_OPTS -and $ProfileTools.eza) {
    $env:_ZO_FZF_OPTS = "--preview='eza --tree --level=1 --icons --color=always {2..}' --preview-window=right,40%"
}

# This defines the global functions and sets the aliases:
#   cd   __zoxide_z    jump by keyword, or to a path as usual (also `cd -`, `cd +`, and `cd` alone for home)
#   cdi  __zoxide_zi   pick from a list with fzf
# --hook none because zoxide's PowerShell hook wraps `prompt`, which would break the red caret
# on a failed command; directories are recorded by the location-changed hook below instead. The
# init script replaces the built-in cd alias itself (Set-Alias -Force), so no Remove-Alias here.
Invoke-Expression ((& $ProfileTools.zoxide init powershell --cmd cd --hook none) -join "`n")

# Record every directory change in zoxide's database, however you got there (cd, Set-Location,
# yazi). Any hook that was already registered is kept and called afterwards. Loading this twice
# (e.g. `. $PROFILE`) must not chain the hook onto itself, so the original is captured once.
if (-not $global:ProfileZoxide) {
    $global:ProfileZoxide = @{ Previous = $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction }
}
$global:ProfileZoxide.Bin = $ProfileTools.zoxide
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($sender, $e)
    $zoxide = $global:ProfileZoxide
    if ($e.NewPath.Provider.Name -eq 'FileSystem') { & $zoxide.Bin add '--' $e.NewPath.ProviderPath }
    if ($zoxide.Previous) { $zoxide.Previous.Invoke($sender, $e) }
}
