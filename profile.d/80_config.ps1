# Read and change profile settings. Settings and their defaults live in config.ps1
# ($ProfileConfigSpecs); your own values live in config.local.ps1, which these commands create and
# edit. Only lines of the form  $env:NAME = 'value'  are managed; comments, blank lines and any
# other code in that file are left exactly as they are.
#
#   Get-ProfileConfig [-Name ...]        list settings with value, default and where the value comes from
#   Set-ProfileConfig NAME VALUE | -Reset  change one setting (validated), saved and applied now
#   Edit-ProfileConfig  (cfg)            interactive settings screen

$script:ConfigLocalPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config.local.ps1'

$script:ConfigHeader = @(
    '# Local overrides for config.ps1 (see config.local.ps1.example). Lines of the form'
    "#     `$env:NAME = 'value'"
    '# are edited by Edit-ProfileConfig / Set-ProfileConfig (alias cfg); everything else here is left alone.'
)

# $env:NAME = 'value'   # optional comment   (a quote inside the value is doubled)
$script:ConfigLinePattern = '^(?<indent>\s*)\$env:(?<name>[A-Za-z_]\w*)\s*=\s*' + "'" +
    '(?<value>(?:[^' + "'" + ']|' + "''" + ')*)' + "'" + '(?<tail>\s*(?:#.*)?)$'

# ---------------------------------------------------------------------------------------------
# Text handling for config.local.ps1 (pure functions: text in, text out)
# ---------------------------------------------------------------------------------------------

function script:Split-ConfigText {
    param([string]$Text)
    $lines = [Collections.Generic.List[string]]::new()
    $final = $Text.EndsWith("`n")
    if ($Text) { $lines.AddRange([string[]]($Text -split "`r?`n")) }
    if ($final -and $lines.Count) { $lines.RemoveAt($lines.Count - 1) }   # empty piece after the last newline
    [pscustomobject]@{ Lines = $lines; Newline = ($Text.Contains("`r`n") ? "`r`n" : "`n"); FinalNewline = $final }
}

function script:Join-ConfigText {
    param($Parts)
    ($Parts.Lines -join $Parts.Newline) + ($Parts.FinalNewline -and $Parts.Lines.Count ? $Parts.Newline : '')
}

# name -> value for every managed line (the last one wins, as it would when the file runs).
function script:Get-ConfigTextValues {
    param([string]$Text)
    $values = @{}
    foreach ($line in (Split-ConfigText $Text).Lines) {
        $m = [regex]::Match($line, $script:ConfigLinePattern)
        if ($m.Success) { $values[$m.Groups['name'].Value] = $m.Groups['value'].Value.Replace("''", "'") }
    }
    $values
}

# Sets a managed line: updates every existing line for the name (keeping indent and trailing
# comment), or appends one. An empty or missing file gets the header first.
function script:Set-ConfigText {
    param([string]$Text, [string]$Name, [string]$Value)
    $parts = Split-ConfigText $Text
    $escaped = $Value.Replace("'", "''")
    $found = $false
    for ($i = 0; $i -lt $parts.Lines.Count; $i++) {
        $m = [regex]::Match($parts.Lines[$i], $script:ConfigLinePattern)
        if ($m.Success -and $m.Groups['name'].Value -ieq $Name) {
            $parts.Lines[$i] = "$($m.Groups['indent'].Value)`$env:$($m.Groups['name'].Value) = '$escaped'$($m.Groups['tail'].Value)"
            $found = $true
        }
    }
    if (-not $found) {
        if (-not $parts.Lines.Count) { $parts.Lines.AddRange([string[]]$script:ConfigHeader); $parts.Lines.Add('') }
        $parts.Lines.Add("`$env:$Name = '$escaped'")
        $parts.FinalNewline = $true
    }
    Join-ConfigText $parts
}

function script:Remove-ConfigText {
    param([string]$Text, [string]$Name)
    $parts = Split-ConfigText $Text
    [void]$parts.Lines.RemoveAll([Predicate[string]] {
            param($line)
            $m = [regex]::Match($line, $script:ConfigLinePattern)
            $m.Success -and $m.Groups['name'].Value -ieq $Name
        })
    Join-ConfigText $parts
}

# Returns an error message when the value is not allowed for the setting, otherwise $null.
function script:Get-ConfigValueError {
    param($Spec, [string]$Value)
    switch ($Spec.Type) {
        'bool' { if ($Value -notin '0', '1') { return "$($Spec.Name) must be 1 or 0, not '$Value'." } }
        'choice' { if ($Value -notin $Spec.Values) { return "$($Spec.Name) must be one of: $($Spec.Values -join ', '). Got '$Value'." } }
        'int' {
            $n = 0
            if (-not [int]::TryParse($Value, [ref]$n)) { return "$($Spec.Name) must be a whole number, not '$Value'." }
            if ($null -ne $Spec.Min -and $n -lt $Spec.Min) { return "$($Spec.Name) must be at least $($Spec.Min). Got $n." }
            if ($null -ne $Spec.Max -and $n -gt $Spec.Max) { return "$($Spec.Name) must be at most $($Spec.Max). Got $n." }
        }
    }
}

function script:Read-ConfigLocalText {
    [IO.File]::Exists($script:ConfigLocalPath) ? [IO.File]::ReadAllText($script:ConfigLocalPath) : ''
}

# ---------------------------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------------------------

function Get-ProfileConfig {
    <#
    .SYNOPSIS
        List profile settings with their current value, default and source.
    .DESCRIPTION
        Source is 'default', 'local' (the value in config.local.ps1 is the one in effect), 'session'
        (changed in this session since the file was applied) or 'environment' (inherited from the
        environment the shell started in). Valid says whether the current value is allowed.
    .PARAMETER Name
        Setting names or wildcards. All settings when omitted.
    .NOTES
        Requires: nothing
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][string[]]$Name)

    $local = Get-ConfigTextValues (Read-ConfigLocalText)
    foreach ($spec in $global:ProfileConfigSpecs) {
        if ($Name -and -not ($Name | Where-Object { $spec.Name -like $_ })) { continue }
        $value = [Environment]::GetEnvironmentVariable($spec.Name)
        $source = if ($local.ContainsKey($spec.Name)) { $value -eq $local[$spec.Name] ? 'local' : 'session' }
        else { $value -eq $spec.Default ? 'default' : 'environment' }
        [pscustomobject]@{
            PSTypeName  = 'ProfileConfig'
            Name        = $spec.Name
            Value       = $value
            Default     = $spec.Default
            Source      = $source
            Valid       = -not (Get-ConfigValueError $spec $value)
            Type        = $spec.Type
            Values      = $spec.Values
            Min         = $spec.Min
            Max         = $spec.Max
            Group       = $spec.Group
            Description = $spec.Description
        }
    }
}

function Set-ProfileConfig {
    <#
    .SYNOPSIS
        Change a profile setting: validate it, save it to config.local.ps1 and apply it now.
    .DESCRIPTION
        A value other than the default is written as a  $env:NAME = 'value'  line in config.local.ps1
        (created if missing). Setting the default, or -Reset, removes the line so the setting follows
        the default again. Nothing else in the file is touched. The change also applies to the
        running session without reloading the profile.
    .EXAMPLE
        Set-ProfileConfig PROFILE_ICONS plain
    .EXAMPLE
        Set-ProfileConfig PROMPT_GIT_MESSAGE_WIDTH -Reset
    .NOTES
        Requires: nothing
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Value')]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Value')][string]$Value,
        [Parameter(Mandatory, ParameterSetName = 'Reset')][switch]$Reset,
        [switch]$PassThru
    )

    $spec = $global:ProfileConfigSpecs | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $spec) { throw "Unknown setting '$Name'. Known settings: $($global:ProfileConfigSpecs.Name -join ', ')." }
    if (-not $Reset) {
        $problem = Get-ConfigValueError $spec $Value
        if ($problem) { throw $problem }
    }

    $toDefault = $Reset -or $Value -eq $spec.Default
    $target = $toDefault ? $spec.Default : $Value
    $old = Read-ConfigLocalText
    $new = $toDefault ? (Remove-ConfigText $old $spec.Name) : (Set-ConfigText $old $spec.Name $Value)

    if ($PSCmdlet.ShouldProcess($script:ConfigLocalPath, "Set $($spec.Name) = $target")) {
        if ($new -cne $old) { [IO.File]::WriteAllText($script:ConfigLocalPath, $new, [Text.UTF8Encoding]::new($false)) }
        [Environment]::SetEnvironmentVariable($spec.Name, $target, 'Process')
        # Recorded as applied by the config loader, so a reload clears and recomputes it from the file.
        $global:ProfileConfigApplied[$spec.Name] = $target
    }
    if ($PassThru) { Get-ProfileConfig -Name $spec.Name }
}

function Edit-ProfileConfig {
    <#
    .SYNOPSIS
        Interactive settings screen: change profile settings with the keyboard.
    .DESCRIPTION
        Up/Down choose a setting, Enter changes it (a toggle flips, a choice opens a list, a number
        opens a spinner), D resets it to its default, Esc leaves. Each change is saved to
        config.local.ps1 and applied at once. Settings still on their default are not written to
        the file.
    .NOTES
        Aliases: cfg
    #>
    [CmdletBinding()]
    param()
    Assert-Console
    $io = $script:ConsoleIO
    $esc = $script:ConsoleEsc
    $status = ''
    $selected = 0

    while ($true) {
        $settings = @(Get-ProfileConfig)
        $nameWidth = ($settings.Name | Measure-Object -Property Length -Maximum).Maximum
        $valueWidth = [Math]::Max(5, ($settings.Value | Measure-Object -Property Length -Maximum).Maximum)
        $rows = $settings | ForEach-Object {
            $mark = switch ($_.Source) { 'local' { '* local' } 'session' { '~ session' } 'environment' { '~ environment' } default { '' } }
            "$($_.Name.PadRight($nameWidth))  $($_.Value.PadRight($valueWidth))  $mark" + ($_.Valid ? '' : '  (invalid!)')
        }
        $details = {
            param($i)
            $s = $settings[$i]
            $width = [Math]::Max(20, (& $io.Size).Width - 2)
            $allowed = switch ($s.Type) {
                'bool' { '1 (on) or 0 (off)' }
                'choice' { $s.Values -join ' or ' }
                'int' { "a number from $($s.Min) to $($s.Max)" }
            }
            $lines = @('')
            $lines += Format-ConsoleWrapped $s.Description $width
            $lines += "$esc[90mDefault: $($s.Default)   Allowed: $allowed   Group: $($s.Group)$esc[0m"
            $lines += $status ? "$esc[32m$status$esc[0m" : ''
            $lines
        }

        $pick = Read-ConsoleSelect -Title 'Profile settings   (* = overridden in config.local.ps1)' -Items $rows -Default $selected `
            -Details $details -ReturnOnKey 'd' -HintExtra 'D resets to default' -Transient
        if ($pick.Cancelled) { break }
        $selected = $pick.Index
        $s = $settings[$selected]

        try {
            if ($pick.Key) {
                Set-ProfileConfig -Name $s.Name -Reset
                $status = "$($s.Name) reset to its default ($($s.Default))."
                continue
            }
            $new = switch ($s.Type) {
                'bool' { $s.Value -eq '1' ? '0' : '1' }
                'choice' {
                    $at = [Array]::IndexOf([string[]]$s.Values, $s.Value)
                    $r = Read-ConsoleSelect -Title "$($s.Name):" -Items $s.Values -Default ([Math]::Max(0, $at)) -Transient
                    if (-not $r.Cancelled) { $s.Values[$r.Index] }
                }
                'int' {
                    $start = 0
                    if (-not [int]::TryParse($s.Value, [ref]$start)) { $start = [int]$s.Default }
                    $n = Read-ConsoleNumber -Title $s.Name -Value $start -Min $s.Min -Max $s.Max -Transient
                    if ($null -ne $n) { "$n" }
                }
            }
            if ($null -eq $new) { $status = ''; continue }
            Set-ProfileConfig -Name $s.Name -Value $new
            $status = $new -eq $s.Default ? "$($s.Name) is back to its default ($new); override removed." : "$($s.Name) = $new  (saved to config.local.ps1, applied)"
        }
        catch { $status = "Could not change $($s.Name): $($_.Exception.Message)" }
    }
}

# ---------------------------------------------------------------------------------------------
# Tab completion and alias
# ---------------------------------------------------------------------------------------------

Register-ArgumentCompleter -CommandName Get-ProfileConfig, Set-ProfileConfig -ParameterName Name -ScriptBlock {
    param($command, $parameter, $word)
    $global:ProfileConfigSpecs.Name | Where-Object { $_ -like "$word*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

Register-ArgumentCompleter -CommandName Set-ProfileConfig -ParameterName Value -ScriptBlock {
    param($command, $parameter, $word, $ast, $fakeBound)
    $spec = $global:ProfileConfigSpecs | Where-Object { $_.Name -eq $fakeBound['Name'] } | Select-Object -First 1
    if (-not $spec) { return }
    $options = switch ($spec.Type) { 'bool' { '1', '0' } 'choice' { $spec.Values } default { $spec.Default } }
    $options | Where-Object { $_ -like "$word*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "$($spec.Name) = $_") }
}

Set-Alias -Name cfg -Value Edit-ProfileConfig
