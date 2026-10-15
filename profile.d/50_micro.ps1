if (-not $ProfileTools.micro) { return }

# Read settings and bindings from the repo's .config\micro, unless MICRO_CONFIG_HOME is already set.
# micro also keeps its buffer history and plugins there (git ignores them).
if (-not $env:MICRO_CONFIG_HOME) {
    $microConfig = Get-ProfileToolConfig 'micro'
    if ($microConfig) { $env:MICRO_CONFIG_HOME = $microConfig }
    Remove-Variable microConfig
}

# Make micro the editor for git commit messages and other tools that read EDITOR, unless it is
# already set (audit warns when it points elsewhere). It points at bin\micro-edit.ps1, which runs
# micro and, inside Claude Code (which starts $EDITOR itself, bypassing the alias below), opens it
# in its own window. The path is quoted in case the repo lives in a folder with spaces. Falls back
# to the bare name if the script is missing.
if (-not $env:EDITOR) {
    $microEdit = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\micro-edit.ps1'
    $env:EDITOR = if ([IO.File]::Exists($microEdit)) { "pwsh -NoProfile -File `"$microEdit`"" } else { 'micro' }
    Remove-Variable microEdit
}

function Invoke-Micro {
    <#
    .SYNOPSIS
        micro, opened in its own terminal window when run inside Claude Code.
    .DESCRIPTION
        Inside Claude Code (CLAUDECODE is set) micro stops responding, so it is started in a
        separate window instead and this call waits until that window closes, then returns micro's
        exit code. Everywhere else it is plain micro. Piped input always runs in place, since a new
        window cannot receive it. Call micro.exe directly to skip the wrapper.
    .NOTES
        Requires: micro
        Aliases: micro
    #>
    if (-not $env:CLAUDECODE -or $MyInvocation.ExpectingInput) {
        if ($MyInvocation.ExpectingInput) { $input | & $ProfileTools.micro @args } else { & $ProfileTools.micro @args }
        return
    }

    # Start-Process joins the arguments with spaces and does not quote them, so quote the ones
    # that need it. The new window starts in the current folder.
    $microArgs = foreach ($arg in $args) {
        if ($arg -match '[\s"]') { '"' + ($arg -replace '"', '\"') + '"' } else { "$arg" }
    }
    $startArgs = @{
        FilePath         = $ProfileTools.micro
        WorkingDirectory = (Get-Location).ProviderPath
        Wait             = $true
        PassThru         = $true
    }
    if ($microArgs) { $startArgs.ArgumentList = $microArgs }
    $process = Start-Process @startArgs
    $global:LASTEXITCODE = $process.ExitCode
}

Set-Alias -Name micro -Value Invoke-Micro
