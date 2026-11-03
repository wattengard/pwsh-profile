function Show-ProfileBanner {
    <#
    .SYNOPSIS
        Prints the PowerShell logo next to a few system facts.
    .DESCRIPTION
        A slanted blue PowerShell logo drawn with truecolor background cells, beside the user and
        machine, PowerShell and OS versions, uptime, current directory and a color palette. Shown
        at startup when PROFILE_BANNER is 1 and the shell is interactive; run it by hand any time.
        With PROFILE_ICONS=plain the rows have no Nerd Font glyphs. Needs a truecolor terminal.
    .NOTES
        Requires: nothing (Nerd Font for PROFILE_ICONS=nerd)
        Aliases: banner
    #>
    $e = [char]27
    $reset = "$e[0m"
    $nerd = $env:PROFILE_ICONS -ne 'plain'
    function Fg($r, $g, $b) { "$e[38;2;${r};${g};${b}m" }
    function Bg($r, $g, $b) { "$e[48;2;${r};${g};${b}m" }
    function Icon([int]$cp) { if ($nerd) { [char]::ConvertFromUtf32($cp) + ' ' } else { '' } }

    # Slanted blue plate with a white ">" chevron and "_" cursor
    $rows = 9
    $bodyW = 22
    $slant = $rows - 1                 # left padding shrinks one column per row
    $logoCols = $slant + $bodyW + 2
    $chevron = @{ 1 = 3; 2 = 5; 3 = 7; 4 = 7; 5 = 5; 6 = 3 }   # row -> start column, 3 wide
    $top = 0x4C, 0x9B, 0xF0
    $bottom = 0x0B, 0x3A, 0x8C
    $white = Bg 255 255 255

    $logo = for ($r = 0; $r -lt $rows; $r++) {
        $t = $r / ($rows - 1)
        $c = 0..2 | ForEach-Object { [int]($top[$_] + ($bottom[$_] - $top[$_]) * $t) }
        $plate = Bg $c[0] $c[1] $c[2]
        $sb = [Text.StringBuilder]::new((' ' * ($slant - $r)))
        for ($x = 0; $x -lt $bodyW; $x++) {
            $isWhite = ($chevron.ContainsKey($r) -and $x -ge $chevron[$r] -and $x -lt $chevron[$r] + 3) -or
                       ($r -eq 7 -and $x -ge 11 -and $x -lt 19)
            [void]$sb.Append($(if ($isWhite) { $white } else { $plate })).Append(' ')
        }
        [void]$sb.Append($reset).Append(' ' * ($logoCols - $slant + $r - $bodyW))
        $sb.ToString()
    }

    $up = [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
    $os = [Runtime.InteropServices.RuntimeInformation]::OSDescription
    $machine = [Environment]::MachineName
    function Row($icon, $label, $value, $r, $g, $b) { "$(Fg $r $g $b)$icon$label$reset  $value" }
    $palette = '40;42;54', '255;85;85', '80;250;123', '241;250;140', '98;114;164', '255;121;198', '139;233;253', '248;248;242'
    $info = @(
        "$(Fg 76 155 240)$env:USERNAME$reset$(Fg 150 150 150)@$reset$(Fg 255 191 71)$machine$reset"
        "$(Fg 90 90 90)$([string][char]0x2500 * 28)$reset"
        (Row (Icon 0xF0A0A) 'PS  ' $PSVersionTable.PSVersion 76 155 240)
        (Row (Icon 0xF17A) 'OS  ' $os 0 200 255)
        (Row (Icon 0xF108) 'Host' $machine 180 130 255)
        (Row (Icon 0xF017) 'Up  ' "$($up.Days)d $($up.Hours)h $($up.Minutes)m" 120 220 120)
        (Row (Icon 0xF07C) 'Dir ' (Get-Location).Path 255 191 71)
        ''
        (($palette | ForEach-Object { "$e[48;2;${_}m   $reset" }) -join '')
    )

    # [Console]::WriteLine uses the console's output encoding, often an OEM code page that turns
    # Nerd Font glyphs into "?". Switch to UTF-8 for the write only, then put the old one back.
    $oldEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        for ($i = 0; $i -lt $rows; $i++) {
            $line = $logo[$i]
            if ($i -lt $info.Count) { $line += $info[$i] }
            [Console]::WriteLine($line)
        }
    }
    finally { [Console]::OutputEncoding = $oldEncoding }
}

Set-Alias -Name banner -Value Show-ProfileBanner

# Interactive shells only, so scripts, -Command runs and tool shells stay quiet.
if ($env:PROFILE_BANNER -ne '0' -and -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected) {
    Show-ProfileBanner
}
