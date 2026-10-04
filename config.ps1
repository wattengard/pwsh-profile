# Profile configuration, dot-sourced by bootstrap.ps1 before profile.d.
# Values already set in the environment win, so you can override per session or machine.

$defaults = [ordered]@{
    # Show the current commit's subject after the git branch in the prompt (1 = on, 0 = off).
    PROMPT_GIT_MESSAGE       = '1'
    # Max characters of the commit subject to show; longer subjects are cut with an ellipsis.
    PROMPT_GIT_MESSAGE_WIDTH = '40'
}

foreach ($name in $defaults.Keys) {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        [Environment]::SetEnvironmentVariable($name, $defaults[$name], 'Process')
    }
}

Remove-Variable defaults, name
