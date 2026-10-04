# Key-driven console widgets built from [Console]::ReadKey and ANSI escapes, no external tools:
# a select / multi-select list, on/off toggles, a number spinner and a line editor. They are
# building blocks for tools like Edit-ProfileConfig and need an interactive terminal.
#
# All key input, output, console size and the interactivity check go through $script:ConsoleIO,
# so tests can swap in scripted keys and capture the output. The *Lines functions only build
# text and are testable without a console.

$script:ConsoleEsc = [char]27

$script:ConsoleIO = @{
    ReadKey     = { [Console]::ReadKey($true) }
    Write       = { param($text) [Console]::Write($text) }
    Size        = { [pscustomobject]@{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight } }
    Interactive = { -not ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) }
}

function script:Write-Console {
    param([string]$Text)
    & $script:ConsoleIO.Write $Text
}

function script:Assert-Console {
    if (-not (& $script:ConsoleIO.Interactive)) { throw 'This needs an interactive terminal (input and output cannot be redirected).' }
}

# Cuts plain text to a width with an ellipsis. Apply it before adding color codes.
function script:Limit-ConsoleText {
    param([string]$Text, [int]$Max)
    if ($Max -lt 2 -or $Text.Length -le $Max) { return $Text }
    $Text.Substring(0, $Max - 1) + '…'
}

# Word-wraps text to a width and returns the lines.
function script:Format-ConsoleWrapped {
    param([string]$Text, [int]$Width, [string]$Indent = '')
    $lines = [Collections.Generic.List[string]]::new()
    $current = ''
    foreach ($word in $Text -split '\s+' | Where-Object { $_ }) {
        if ($current -and ($Indent.Length + $current.Length + 1 + $word.Length) -gt $Width) { $lines.Add($Indent + $current); $current = $word }
        else { $current = $current ? "$current $word" : $word }
    }
    if ($current) { $lines.Add($Indent + $current) }
    $lines
}

# Redraws a block of lines in place. The block never shrinks (extra lines are blanked) so the
# screen does not jump when a details area changes height.
function script:Write-ConsoleBlock {
    param([string[]]$Lines, [ref]$Drawn)
    $esc = $script:ConsoleEsc
    $height = [Math]::Max($Drawn.Value, $Lines.Count)
    $out = [Text.StringBuilder]::new()
    if ($Drawn.Value -gt 0) { [void]$out.Append("$esc[$($Drawn.Value)A") }
    for ($i = 0; $i -lt $height; $i++) {
        [void]$out.Append("$esc[2K")
        if ($i -lt $Lines.Count) { [void]$out.Append($Lines[$i]) }
        [void]$out.Append("`n")
    }
    Write-Console $out.ToString()
    $Drawn.Value = $height
}

function script:Clear-ConsoleBlock {
    param([int]$Drawn)
    if ($Drawn -gt 0) { Write-Console ("$($script:ConsoleEsc)[$($Drawn)A$($script:ConsoleEsc)[J") }
}

function script:Get-ConsoleSelectLines {
    param(
        [string]$Title, [string[]]$Items, [int]$Index, [bool[]]$Marks, [switch]$Multi,
        [int]$Top = 0, [int]$Visible = 0, [int]$Width = 0, [string]$HintExtra = '', [string[]]$Details = @()
    )
    $esc = $script:ConsoleEsc
    $max = $Width ? $Width - 1 : 0
    $hint = $Multi ? 'Up/Down move, Space toggles, A all/none, Enter accepts, Esc cancels' : 'Up/Down move, Enter selects, Esc cancels'
    if ($HintExtra) { $hint += ", $HintExtra" }
    $lines = @("$esc[1m$(Limit-ConsoleText $Title $max)$esc[0m", "$esc[90m$(Limit-ConsoleText $hint $max)$esc[0m")

    $scrolling = $Visible -gt 0 -and $Visible -lt $Items.Count
    $end = $scrolling ? $Top + $Visible : $Items.Count
    if (-not $scrolling) { $Top = 0 }
    if ($scrolling) { $lines += $Top -gt 0 ? "$esc[90m  ↑ $Top more$esc[0m" : '' }
    for ($i = $Top; $i -lt $end; $i++) {
        $box = $Multi ? ($Marks[$i] ? '[x] ' : '[ ] ') : ''
        $text = Limit-ConsoleText "$($i -eq $Index ? '>' : ' ') $box$($Items[$i])" $max
        $lines += $i -eq $Index ? "$esc[36m$text$esc[0m" : $text
    }
    if ($scrolling) { $below = $Items.Count - $end; $lines += $below -gt 0 ? "$esc[90m  ↓ $below more$esc[0m" : '' }
    foreach ($detail in $Details) { $lines += $detail }
    $lines
}

function script:Get-ConsoleToggleLines {
    param([string]$Title, [string[]]$Names, [bool[]]$States, [int]$Index, [int]$Width = 0)
    $esc = $script:ConsoleEsc
    $max = $Width ? $Width - 1 : 0
    $lines = @("$esc[1m$(Limit-ConsoleText $Title $max)$esc[0m", "$esc[90m$(Limit-ConsoleText 'Up/Down move, Space or Left/Right flips, Enter accepts, Esc cancels' $max)$esc[0m")
    $pad = ($Names | Measure-Object -Property Length -Maximum).Maximum
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $state = $States[$i] ? "$esc[32m[ ON  ]$esc[0m" : "$esc[31m[ OFF ]$esc[0m"
        $text = "$($i -eq $Index ? '>' : ' ') $($Names[$i].PadRight($pad))  "
        $lines += ($i -eq $Index ? "$esc[36m$text$esc[0m" : $text) + $state
    }
    $lines
}

function Read-ConsoleSelect {
    <#
    .SYNOPSIS
        A key-driven select or multi-select list.
    .DESCRIPTION
        Up/Down/Home/End move, Enter accepts, Esc cancels; Space toggles and A selects all or none
        when -Multi is set. Long lists scroll. Returns an object with Cancelled, Index (the
        highlighted row), Indexes (the checked rows, for -Multi) and Key (the key that ended it
        when it was one of -ReturnOnKey, otherwise null).
    .PARAMETER Details
        A scriptblock called with the highlighted index; the lines it returns are shown under the list.
    .PARAMETER ReturnOnKey
        Extra single-character keys that end the list and are reported in Key (e.g. 'd').
    .PARAMETER HintExtra
        Text appended to the hint line, to advertise the -ReturnOnKey keys.
    .PARAMETER Transient
        Erase the list from the screen when it returns.
    .NOTES
        Needs an interactive terminal.
    #>
    param(
        [string]$Title, [string[]]$Items, [switch]$Multi, [int]$Default = 0, [bool[]]$Checked,
        [scriptblock]$Details, [char[]]$ReturnOnKey = @(), [string]$HintExtra = '', [switch]$Transient
    )
    Assert-Console
    $io = $script:ConsoleIO
    $index = [Math]::Min([Math]::Max(0, $Default), [Math]::Max(0, $Items.Count - 1))
    $marks = [bool[]]::new($Items.Count)
    if ($Checked) { for ($i = 0; $i -lt $Items.Count; $i++) { $marks[$i] = $Checked[$i] } }
    $top = 0
    $drawn = 0
    $result = $null
    Write-Console ("$($script:ConsoleEsc)[?25l")
    try {
        while (-not $result) {
            $size = & $io.Size
            $detailLines = $Details ? @(& $Details $index) : @()
            $visible = [Math]::Min($Items.Count, [Math]::Max(3, $size.Height - 6 - $detailLines.Count))
            if ($index -lt $top) { $top = $index }
            if ($index -ge $top + $visible) { $top = $index - $visible + 1 }
            Write-ConsoleBlock (Get-ConsoleSelectLines -Title $Title -Items $Items -Index $index -Marks $marks -Multi:$Multi `
                    -Top $top -Visible $visible -Width $size.Width -HintExtra $HintExtra -Details $detailLines) ([ref]$drawn)

            $key = & $io.ReadKey
            switch ($key.Key) {
                'UpArrow' { $index = ($index - 1 + $Items.Count) % $Items.Count }
                'DownArrow' { $index = ($index + 1) % $Items.Count }
                'Home' { $index = 0 }
                'End' { $index = $Items.Count - 1 }
                'Spacebar' { if ($Multi) { $marks[$index] = -not $marks[$index] } }
                'Escape' { $result = [pscustomobject]@{ Cancelled = $true; Index = -1; Indexes = @(); Key = $null } }
                'Enter' {
                    $result = [pscustomobject]@{
                        Cancelled = $false; Index = $index; Key = $null
                        Indexes   = @(0..($Items.Count - 1) | Where-Object { $marks[$_] })
                    }
                }
                default {
                    if ($key.KeyChar -ne [char]0 -and "$($key.KeyChar)" -in $ReturnOnKey) {
                        $result = [pscustomobject]@{ Cancelled = $false; Index = $index; Indexes = @(); Key = "$($key.KeyChar)" }
                    }
                    elseif ($Multi -and $key.KeyChar -in 'a', 'A') {
                        $all = $marks -notcontains $false
                        for ($i = 0; $i -lt $marks.Count; $i++) { $marks[$i] = -not $all }
                    }
                }
            }
        }
    }
    finally {
        if ($Transient) { Clear-ConsoleBlock $drawn }
        Write-Console ("$($script:ConsoleEsc)[?25h")
    }
    $result
}

function Read-ConsoleToggle {
    <#
    .SYNOPSIS
        A list of on/off switches. Returns an ordered hashtable of name to bool, or $null if cancelled.
    .NOTES
        Needs an interactive terminal.
    #>
    param([string]$Title, [string[]]$Names, [bool[]]$States, [switch]$Transient)
    Assert-Console
    $io = $script:ConsoleIO
    $state = [bool[]]::new($Names.Count)
    if ($States) { for ($i = 0; $i -lt $Names.Count; $i++) { $state[$i] = $States[$i] } }
    $index = 0
    $drawn = 0
    $done = $false
    $result = $null
    Write-Console ("$($script:ConsoleEsc)[?25l")
    try {
        while (-not $done) {
            Write-ConsoleBlock (Get-ConsoleToggleLines -Title $Title -Names $Names -States $state -Index $index -Width (& $io.Size).Width) ([ref]$drawn)
            $key = & $io.ReadKey
            switch ($key.Key) {
                'UpArrow' { $index = ($index - 1 + $Names.Count) % $Names.Count }
                'DownArrow' { $index = ($index + 1) % $Names.Count }
                { $_ -in 'Spacebar', 'LeftArrow', 'RightArrow' } { $state[$index] = -not $state[$index] }
                'Escape' { $done = $true }
                'Enter' {
                    $result = [ordered]@{}
                    for ($i = 0; $i -lt $Names.Count; $i++) { $result[$Names[$i]] = $state[$i] }
                    $done = $true
                }
            }
        }
    }
    finally {
        if ($Transient) { Clear-ConsoleBlock $drawn }
        Write-Console ("$($script:ConsoleEsc)[?25h")
    }
    $result
}

function Read-ConsoleNumber {
    <#
    .SYNOPSIS
        A number chosen with Up/Down (step), PageUp/PageDown (ten steps), Home/End (min/max) or typed
        digits. Returns the number, or $null if cancelled.
    .NOTES
        Needs an interactive terminal.
    #>
    param([string]$Title, [int]$Value = 0, [int]$Min = 0, [int]$Max = 100, [int]$Step = 1, [switch]$Transient)
    Assert-Console
    $io = $script:ConsoleIO
    $esc = $script:ConsoleEsc
    $clamp = { param($n) [Math]::Min($Max, [Math]::Max($Min, $n)) }
    $Value = & $clamp $Value
    $typed = ''
    $done = $false
    $result = $null
    Write-Console ("$esc[?25l")
    try {
        while (-not $done) {
            $width = (& $io.Size).Width
            $line = Limit-ConsoleText "$Title  < $Value >  ($Min..$Max; Up/Down, PgUp/PgDn, digits, Enter, Esc)" ($width - 1)
            Write-Console ("`r$esc[2K$esc[36m$line$esc[0m")
            $key = & $io.ReadKey
            switch ($key.Key) {
                'UpArrow' { $Value = & $clamp ($Value + $Step); $typed = '' }
                'DownArrow' { $Value = & $clamp ($Value - $Step); $typed = '' }
                'PageUp' { $Value = & $clamp ($Value + 10 * $Step); $typed = '' }
                'PageDown' { $Value = & $clamp ($Value - 10 * $Step); $typed = '' }
                'Home' { $Value = $Min; $typed = '' }
                'End' { $Value = $Max; $typed = '' }
                'Backspace' {
                    if ($typed.Length) {
                        $typed = $typed.Substring(0, $typed.Length - 1)
                        $Value = $typed ? (& $clamp ([int]$typed)) : $Min
                    }
                }
                'Escape' { $done = $true }
                'Enter' { $result = $Value; $done = $true }
                default {
                    if ($key.KeyChar -match '\d' -and $typed.Length -lt 9) { $typed += $key.KeyChar; $Value = & $clamp ([int]$typed) }
                }
            }
        }
    }
    finally {
        Write-Console ($Transient ? "`r$esc[2K" : "`n")
        Write-Console ("$esc[?25h")
    }
    $result
}

function Read-ConsoleLine {
    <#
    .SYNOPSIS
        A line of text with cursor movement (Left/Right/Home/End/Backspace/Delete). Returns the text,
        or $null if cancelled with Esc.
    .NOTES
        Needs an interactive terminal.
    #>
    param([string]$Prompt, [string]$Text = '', [switch]$Transient)
    Assert-Console
    $io = $script:ConsoleIO
    $esc = $script:ConsoleEsc
    $cursor = $Text.Length
    $done = $false
    $result = $null
    try {
        while (-not $done) {
            Write-Console ("`r$esc[2K$Prompt$Text$esc[$($Prompt.Length + $cursor + 1)G")
            $key = & $io.ReadKey
            switch ($key.Key) {
                'LeftArrow' { if ($cursor -gt 0) { $cursor-- } }
                'RightArrow' { if ($cursor -lt $Text.Length) { $cursor++ } }
                'Home' { $cursor = 0 }
                'End' { $cursor = $Text.Length }
                'Backspace' { if ($cursor -gt 0) { $Text = $Text.Remove($cursor - 1, 1); $cursor-- } }
                'Delete' { if ($cursor -lt $Text.Length) { $Text = $Text.Remove($cursor, 1) } }
                'Escape' { $done = $true }
                'Enter' { $result = $Text; $done = $true }
                default { if (-not [char]::IsControl($key.KeyChar)) { $Text = $Text.Insert($cursor, [string]$key.KeyChar); $cursor++ } }
            }
        }
    }
    finally { Write-Console ($Transient ? "`r$esc[2K" : "`n") }
    $result
}
