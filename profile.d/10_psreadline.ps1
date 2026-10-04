# PSReadLine defaults: history, completion, key bindings and Catppuccin Mocha colors.
# fzf-based Ctrl+R history search lives in 50_fzf.ps1.
#
# Predictions and colors throw when the console is redirected (pwsh -Command in a script,
# CI, a tool shell), so this fragment only applies in a real interactive console.
if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }

Set-PSReadLineOption `
    -EditMode Windows `
    -BellStyle None `
    -MaximumHistoryCount 10000 `
    -HistoryNoDuplicates `
    -HistorySearchCursorMovesToEnd `
    -PredictionSource HistoryAndPlugin `
    -PredictionViewStyle InlineView

# Up/Down search history for the text already typed (type "git " then Up).
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Tab opens a navigable completion menu instead of cycling through candidates.
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Keep lines that look like they contain secrets out of the history file. They stay in
# memory for the session, so Up-arrow still recalls them until the shell closes.
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)
    if ($line -match '(?i)password|passwd|secret|token|api[_-]?key|-AsPlainText|ConvertTo-SecureString') {
        return [Microsoft.PowerShell.AddToHistoryOption]::MemoryOnly
    }
    [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile
}

# Catppuccin Mocha, matching the bat theme. Needs a truecolor terminal (Windows Terminal is).
$mochaFg = { param([int]$rgb) $PSStyle.Foreground.FromRgb($rgb) }
$mochaBg = { param([int]$rgb) $PSStyle.Background.FromRgb($rgb) }
Set-PSReadLineOption -Colors @{
    Default                = & $mochaFg 0xcdd6f4  # text
    Command                = & $mochaFg 0x89b4fa  # blue
    Parameter              = & $mochaFg 0xf2cdcd  # flamingo
    Keyword                = & $mochaFg 0xcba6f7  # mauve
    String                 = & $mochaFg 0xa6e3a1  # green
    Number                 = & $mochaFg 0xfab387  # peach
    Variable               = & $mochaFg 0xf5c2e7  # pink
    Type                   = & $mochaFg 0xf9e2af  # yellow
    Member                 = & $mochaFg 0x89dceb  # sky
    Operator               = & $mochaFg 0x94e2d5  # teal
    Comment                = & $mochaFg 0x6c7086  # overlay0
    Error                  = & $mochaFg 0xf38ba8  # red
    Emphasis               = & $mochaFg 0xf9e2af  # yellow
    ContinuationPrompt     = & $mochaFg 0x6c7086  # overlay0
    InlinePrediction       = & $mochaFg 0x585b70  # surface2
    ListPrediction         = & $mochaFg 0xcba6f7  # mauve
    ListPredictionSelected = & $mochaBg 0x45475a  # surface1
    Selection              = & $mochaBg 0x45475a  # surface1
}
Remove-Variable mochaFg, mochaBg
