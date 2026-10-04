if (-not $ProfileTools.eza) { return }

$env:EZA_CONFIG_DIR = Join-Path $env:USERPROFILE '.config\eza'

function Invoke-Eza {
    <#
    .SYNOPSIS
        eza as a compact long listing with icons.
    .DESCRIPTION
        Long format including hidden files, without user, time or permissions columns,
        with hyperlinks and unquoted names. Icons are Nerd Font glyphs and are left out
        when PROFILE_ICONS is 'plain'. Extra arguments are passed through to eza.
    .NOTES
        Requires: eza
        Aliases: dir
    #>
    $icons = $env:PROFILE_ICONS -eq 'plain' ? @() : @('--icons')
    eza -l @icons --no-user --no-time --no-permissions -a --hyperlink --no-quotes @args
}

Remove-Alias dir -Force -ErrorAction Ignore
Set-Alias -Name dir -Value Invoke-Eza
