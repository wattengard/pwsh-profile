# Profile configuration, dot-sourced by bootstrap.ps1 before profile.d.
# Values already set in the environment win, so you can override per session or machine.

$defaults = [ordered]@{
    # Show the current commit's subject after the git branch in the prompt (1 = on, 0 = off).
    PROMPT_GIT_MESSAGE       = '1'
    # Max characters of the commit subject to show; longer subjects are cut with an ellipsis.
    PROMPT_GIT_MESSAGE_WIDTH = '40'
    # Show working tree state (staged, modified, untracked, conflicts, ahead/behind) after the
    # branch. Runs one time-capped git status per prompt (1 = on, 0 = off).
    PROMPT_GIT_STATE         = '1'
    # How long the prompt waits for git status, in milliseconds, before showing the last known
    # state and letting git finish in the background.
    PROMPT_GIT_STATE_TIMEOUT_MS = '150'
    # Set the terminal tab title on every prompt: the prompt's path outside a git repo,
    # "repo (branch state)" inside one, e.g. "pwsh-profile (main ↑1 ✎ ?)" (1 = on, 0 = off).
    # The state part follows PROMPT_GIT_STATE.
    PROMPT_TAB_TITLE         = '1'
}

foreach ($name in $defaults.Keys) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        [Environment]::SetEnvironmentVariable($name, $defaults[$name], 'Process')
    }
}

Remove-Variable defaults, name
